# EKS Autoscaling with Karpenter

## What is Karpenter?
[Karpenter](https://karpenter.sh) is an open source controller for Kubernetes which enables auto-scaling. 

## How is Karpenter different than the traditional Cluster Autoscaler?
The main difference is that Karpenter does not rely on node groups like Cluster Autoscaler to expand or contract the cluster. It is claimed that Karpenter is both more performant and cost effective than Cluster Autoscaler. 
More details can be found in [this article](https://towardsdev.com/karpenter-vs-cluster-autoscaler-dd877b91629b).

## How to set up Karpenter on EKS

Scripts to automate deployment of Karpenter in this project have been created following instructions from this [walkthrough](Walktrough: https://karpenter.sh/v0.10.0/getting-started/getting-started-with-eksctl/)

1. Build and run aws-do-eks project, exec into aws-do-eks container.

2. Edit eks-karpenter.yaml as needed

3. Edit `eks.conf`

3.1. set CONFIG=yaml

3.2. set EKS_YAML=./eks-karpenter.yaml

4. Create cluster by executing `./eks-create.sh

5. Refer to scripts in the /eks/deployment/karpenter directory

5.1. Execute `./deploy.sh` to configure the necessary roles and deploy the controller

5.2. Optionally execute `./monitoring-deploy.sh` to enable prometheus/grafana monitoring of Karpenter metrics

5.3. Execute `./provisioner-deploy.sh` to configure Karpenter for the cluster

6. Test Karpenter

6.1. Execute `./test-scale-out.sh

6.2. Use `./logs.sh` script to monitor karpenter operations

6.3. Use `./scale.sh <num_pods>` to change the test scale

6.4. Execute `./test-scale-in.sh` to stop testing

## How to use Kaprenter with EFA

[Certain Amazon EC2 instance types](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html#efa-instance-types) 
are enabled with a high-performance network adapter known as [Elastic Fabric Adapter (EFA)](https://aws.amazon.com/hpc/efa/)

As of version 0.16.3 Karpenter is not able to automatically provision instances when EFA resources are requested.
To enable autoscaling of EFA-enabled instances using Karpenter we can configure a provisioner 
with a custom launch template which enables EFA. When the provisioner is limited 
only to the desired EFA-enabled instance type, Karpenter will automatically create 
instances with EFA adapters to satisfy known resource requests like GPU. 
In order to use the EFA device in a pod, the path `/dev/infiniband` needs to be mounted as a `hostPath` volume. 
This requires the pod to run in privileged mode. To remove this requirement, 
Karpenter needs to be modified to recognize instance types, which have support for EFA. 

An advantage of configuring a traditional cluster with Karpenter is that it enables manuall
and automatic scaling at the same time. We can manually set autoscaling groups to desired 
minimal instance counts, and rely on Karpenter to add nodes to the cluster 
only when excess capacity is needed.

An example of a custom launch template is provided in file [./launch-template-efa-example.json](./launch-template-efa-example.json). An example provisioner configuration is provided in file [./provisioner-efa.yaml](./provisioner-efa.yaml).

A recommended process for setting up Karpenter with EFA is described below:

1. Build and run the aws-do-eks project, exec into aws-do-eks container.

2. Edit eks-karpenter.yaml

2.1. Configure a system node group where Karpenter pods would run

2.2. Add node groups with desired instances that have EFA capabilities

3. Edit `eks.conf

3.1. set CONFIG=yaml

3.2. set EKS_YAML=./eks-karpenter.yaml

4. Create cluster by executing `./eks-create.sh` within the `aws-do-eks` container

5. Refer to scripts in the /eks/deployment/karpenter directory

5.1. Execute `./migrate-auth.sh` and copy the authorization group to your clipboard

```yaml
Example:
- groups:
  - system:bootstrappers
  - system:nodes
  rolearn: arn:aws:iam::${AWS_ACCOUNT_ID}:role/KarpenterInstanceNodeRole
  username: system:node:{{EC2PrivateDNSName}}
```

5.2. Execute `./migrate.sh` to migrate the cluster from autoscaler and deploy Karpenter
When asked to edit the aws-auth configmap, paste the content you copied from your clipboard.

5.3. Modify the launch templates of your node groups
The modified launch template must include the following fields that are required by Karpenter:  
AMI, KeyPairName, NetworkSettings->Advanced Network Configuration->Elastic Fabric Adapter->Enable, IAM instance profile: KarpenterInstanceProfile, Storage->DiskSize: 200GB. Set the default version to be the new template revision. Check that UserData in the template has the Kubelet bootstrap scripts and if EFA is not already in the AMI, the EFA driver install script.    

5.4. Edit and apply file `./provisioner-efa.yaml`
Set instance types, launch template name as needed. If you need to use multiple launch templates, then you would need to configure multiple provisioners.

```bash
kubectl apply -f ./provisioner-efa.yaml
```

6. Test Karpenter

6.1. Execute `./test-scale-out.sh`, you should see EFA-enabled instances get added to the cluster

6.2. Execute `./test-scale-in.sh`, the new instances shoudl be removed from the cluster and terminated

7. Test EFA

7.1. Deploy Kubeflow MPI Operator
	
```bash
cd /eks/deployment/kubeflow/mpi-operator; ./deploy.sh
```

7.2. Build `cuda-efa-nccl-tests` container and push it to ECR
	
```bash
cd /eks/deployment/efa-device-plugin/cuda-efa-nccl-tests
./build.sh
./push.sh
```

7.3. Edit /eks/deployment/efa-device-plugin/test-nccl.yaml and test-nccl-efa.yaml

7.3.1. Replace image with the image you built and pushed to ECR

7.3.2. Comment out unsupported resource requests and limits
  
```yaml
#huigepages-2Mi: 5120Mi
#vpc.amazonaws.com/efa: 1
```  

7.3.3. Set desired number of GPU request and limits
  
```yaml
nvidia.com/gpu: 1
```  

7.4. Execute tests

7.4.1. Execute test with EFA disabled

```bash
cd /eks/deployment/efa-device-plugin
kubectl delete mpijob --all
kubectl apply -f ./test-nccl.yaml
```
		
The worker pods will be in status `Pending` and the launcher pod will be in status `CrashLoopBackOff` until Karpenter adds new nodes to the cluster and the nodes become `Ready`, then the worker and launcher pods will enter the `Running state.
When the launcher pod is in `Running` or `Completed` state extract the pod logs to review the test results.
	
```bash
kubectl logs -f $(kubectl get pods | grep launcher | cut -d ' ' -f 1)
```

Sample output:  

```log
...
[1,0]<stdout>:test-nccl-worker-0:22:22 [0] NCCL INFO Using network Socket
...
[1,0]<stdout>:#                                                              out-of-place                       in-place          
[1,0]<stdout>:#       size         count      type   redop    root     time   algbw   busbw #wrong     time   algbw   busbw #wrong
[1,0]<stdout>:#        (B)    (elements)                               (us)  (GB/s)  (GB/s)            (us)  (GB/s)  (GB/s)       
[1,0]<stdout>:           0             0     float     sum      -1     3.91    0.00    0.00      0     3.88    0.00    0.00      0
[1,0]<stdout>:           0             0     float     sum      -1     3.91    0.00    0.00      0     3.91    0.00    0.00      0
[1,0]<stdout>:           4             1     float     sum      -1    98.77    0.00    0.00      0    99.81    0.00    0.00      0
[1,0]<stdout>:           8             2     float     sum      -1    101.4    0.00    0.00      0    101.8    0.00    0.00      0
[1,0]<stdout>:          16             4     float     sum      -1    105.3    0.00    0.00      0    103.9    0.00    0.00      0
[1,0]<stdout>:          32             8     float     sum      -1    106.3    0.00    0.00      0    106.7    0.00    0.00      0
[1,0]<stdout>:          64            16     float     sum      -1    107.9    0.00    0.00      0    108.8    0.00    0.00      0
[1,0]<stdout>:         128            32     float     sum      -1    109.5    0.00    0.00      0    109.4    0.00    0.00      0
[1,0]<stdout>:         256            64     float     sum      -1    110.5    0.00    0.00      0    109.1    0.00    0.00      0
[1,0]<stdout>:         512           128     float     sum      -1    112.9    0.00    0.00      0    115.3    0.00    0.00      0
[1,0]<stdout>:        1024           256     float     sum      -1    109.0    0.01    0.01      0    109.0    0.01    0.01      0
[1,0]<stdout>:        2048           512     float     sum      -1    109.5    0.02    0.02      0    113.1    0.02    0.02      0
[1,0]<stdout>:        4096          1024     float     sum      -1    106.5    0.04    0.04      0    106.0    0.04    0.04      0
[1,0]<stdout>:        8192          2048     float     sum      -1    111.6    0.07    0.07      0    111.6    0.07    0.07      0
[1,0]<stdout>:       16384          4096     float     sum      -1    155.8    0.11    0.11      0    152.7    0.11    0.11      0
[1,0]<stdout>:       32768          8192     float     sum      -1    194.3    0.17    0.17      0    191.1    0.17    0.17      0
[1,0]<stdout>:       65536         16384     float     sum      -1    262.7    0.25    0.25      0    259.6    0.25    0.25      0
[1,0]<stdout>:      131072         32768     float     sum      -1    290.4    0.45    0.45      0    291.7    0.45    0.45      0
[1,0]<stdout>:      262144         65536     float     sum      -1    383.0    0.68    0.68      0    387.5    0.68    0.68      0
[1,0]<stdout>:      524288        131072     float     sum      -1    542.4    0.97    0.97      0    537.7    0.98    0.98      0
[1,0]<stdout>:     1048576        262144     float     sum      -1    806.7    1.30    1.30      0    804.9    1.30    1.30      0
[1,0]<stdout>:     2097152        524288     float     sum      -1   1384.5    1.51    1.51      0   1359.4    1.54    1.54      0
[1,0]<stdout>:     4194304       1048576     float     sum      -1   2440.7    1.72    1.72      0   2400.4    1.75    1.75      0
[1,0]<stdout>:     8388608       2097152     float     sum      -1   4656.9    1.80    1.80      0   4722.8    1.78    1.78      0
[1,0]<stdout>:    16777216       4194304     float     sum      -1   9082.5    1.85    1.85      0   8985.6    1.87    1.87      0
[1,0]<stdout>:    33554432       8388608     float     sum      -1    17301    1.94    1.94      0    17754    1.89    1.89      0
[1,0]<stdout>:    67108864      16777216     float     sum      -1    35629    1.88    1.88      0    35327    1.90    1.90      0
[1,0]<stdout>:   134217728      33554432     float     sum      -1    67134    2.00    2.00      0    70910    1.89    1.89      0
[1,0]<stdout>:   268435456      67108864     float     sum      -1   133878    2.01    2.01      0   134353    2.00    2.00      0
[1,0]<stdout>:   536870912     134217728     float     sum      -1   263971    2.03    2.03      0   267808    2.00    2.00      0
[1,0]<stdout>:  1073741824     268435456     float     sum      -1   536774    2.00    2.00      0   541545    1.98    1.98      0
[1,0]<stdout>:# Out of bounds values : 0 OK
[1,0]<stdout>:# Avg bus bandwidth    : 0.733914 

```
		
7.4.2. Execute test with EFA enabled

This test assumes that the EFA device plugin has been deployed to the cluster.  
If not, execute `cd /eks/deployment/efa-device-plugin; ./deploy.sh`.

```bash
cd /eks/deployment/efa-device-plugin
kubectl delete mpijob --all
kubectl apply -f ./test-nccl-efa-mount.yaml
```

The worker pods will be in status `Pending` and the launcher pod will be in status `CrashLoopBackOff` until Karpenter adds new nodes to the cluster and the nodes become `Ready`, then the worker and launcher pods will enter the `Running state.

When the launcher pod is in `Running` or `Completed` state extract the pod logs to review the test results.  
			
```bash
kubectl logs -f $(kubectl get pods | grep launcher | cut -d ' ' -f 1)
```

Sample output:

```log
...
[1,1]<stdout>:test-nccl-efa-worker-1:22:22 [0] NCCL INFO NET/OFI Selected Provider is efa
[1,1]<stdout>:test-nccl-efa-worker-1:22:22 [0] NCCL INFO Using network AWS Libfabric
...
[1,0]<stdout>:#                                                              out-of-place                       in-place          
[1,0]<stdout>:#       size         count      type   redop    root     time   algbw   busbw #wrong     time   algbw   busbw #wrong
[1,0]<stdout>:#        (B)    (elements)                               (us)  (GB/s)  (GB/s)            (us)  (GB/s)  (GB/s)       
[1,0]<stdout>:           0             0     float     sum      -1     6.28    0.00    0.00      0     6.35    0.00    0.00      0
[1,0]<stdout>:           0             0     float     sum      -1     6.28    0.00    0.00      0     6.28    0.00    0.00      0
[1,0]<stdout>:           4             1     float     sum      -1    70.19    0.00    0.00      0    69.70    0.00    0.00      0
[1,0]<stdout>:           8             2     float     sum      -1    70.54    0.00    0.00      0    70.23    0.00    0.00      0
[1,0]<stdout>:          16             4     float     sum      -1    70.81    0.00    0.00      0    70.82    0.00    0.00      0
[1,0]<stdout>:          32             8     float     sum      -1    69.52    0.00    0.00      0    69.84    0.00    0.00      0
[1,0]<stdout>:          64            16     float     sum      -1    70.07    0.00    0.00      0    70.48    0.00    0.00      0
[1,0]<stdout>:         128            32     float     sum      -1    70.93    0.00    0.00      0    70.21    0.00    0.00      0
[1,0]<stdout>:         256            64     float     sum      -1    70.64    0.00    0.00      0    71.08    0.00    0.00      0
[1,0]<stdout>:         512           128     float     sum      -1    70.94    0.01    0.01      0    70.24    0.01    0.01      0
[1,0]<stdout>:        1024           256     float     sum      -1    72.98    0.01    0.01      0    72.76    0.01    0.01      0
[1,0]<stdout>:        2048           512     float     sum      -1    73.31    0.03    0.03      0    73.65    0.03    0.03      0
[1,0]<stdout>:        4096          1024     float     sum      -1    75.97    0.05    0.05      0    75.54    0.05    0.05      0
[1,0]<stdout>:        8192          2048     float     sum      -1    84.36    0.10    0.10      0    85.09    0.10    0.10      0
[1,0]<stdout>:       16384          4096     float     sum      -1    91.27    0.18    0.18      0    90.67    0.18    0.18      0
[1,0]<stdout>:       32768          8192     float     sum      -1    103.2    0.32    0.32      0    101.8    0.32    0.32      0
[1,0]<stdout>:       65536         16384     float     sum      -1    127.9    0.51    0.51      0    126.6    0.52    0.52      0
[1,0]<stdout>:      131072         32768     float     sum      -1    185.4    0.71    0.71      0    184.6    0.71    0.71      0
[1,0]<stdout>:      262144         65536     float     sum      -1    363.2    0.72    0.72      0    362.4    0.72    0.72      0
[1,0]<stdout>:      524288        131072     float     sum      -1    719.2    0.73    0.73      0    714.4    0.73    0.73      0
[1,0]<stdout>:     1048576        262144     float     sum      -1   1433.8    0.73    0.73      0   1421.9    0.74    0.74      0
[1,0]<stdout>:     2097152        524288     float     sum      -1   1099.4    1.91    1.91      0   1088.7    1.93    1.93      0
[1,0]<stdout>:     4194304       1048576     float     sum      -1   1933.6    2.17    2.17      0   1897.6    2.21    2.21      0
[1,0]<stdout>:     8388608       2097152     float     sum      -1   3500.0    2.40    2.40      0   3481.5    2.41    2.41      0
[1,0]<stdout>:    16777216       4194304     float     sum      -1   6632.0    2.53    2.53      0   6800.9    2.47    2.47      0
[1,0]<stdout>:    33554432       8388608     float     sum      -1    12997    2.58    2.58      0    12751    2.63    2.63      0
[1,0]<stdout>:    67108864      16777216     float     sum      -1    24521    2.74    2.74      0    24332    2.76    2.76      0
[1,0]<stdout>:   134217728      33554432     float     sum      -1    48033    2.79    2.79      0    47884    2.80    2.80      0
[1,0]<stdout>:   268435456      67108864     float     sum      -1    94498    2.84    2.84      0    94708    2.83    2.83      0
[1,0]<stdout>:   536870912     134217728     float     sum      -1   189806    2.83    2.83      0   189397    2.83    2.83      0
[1,0]<stdout>:  1073741824     268435456     float     sum      -1   378919    2.83    2.83      0   381119    2.82    2.82      0
[1,0]<stdout>:# Out of bounds values : 0 OK
[1,0]<stdout>:# Avg bus bandwidth    : 0.960456 
```

## Driver versions and compatibility

[Elastic Fabric Adapter (EFA)](https://aws.amazon.com/hpc/efa/) relies on [AWS OFI NCCL](https://github.com/aws/aws-ofi-nccl) which allows use of [libfabric](https://github.com/ofiwg/libfabric) as a network provider when running [NVIDIA NCCL](https://github.com/NVIDIA/nccl) applications.

Compatibility information of AWS OFI NCCL with libfabric and NCCL versions is available in the [AWS OFI NCCL Release Notes](https://github.com/aws/aws-ofi-nccl/releases). Also compatibility information of NCCL with versions of CUDA is available in the [NCCL Documentation](https://docs.nvidia.com/deeplearning/nccl/release-notes/rel_2-14-3.html#rel_2-14-3). Frameworks like PyTorch, TensorFlow, etc. also need to be compatible with CUDA and NVIDIA Driver as detailed in the [Framework Containers Support Matrix](https://docs.nvidia.com/deeplearning/frameworks/support-matrix/index.html). Versions of drivers and frameworks that are used in containers, should be compatible with those installed natively on the host machines where these containers run. A sample project for building base Amazon Machine Images (AMI) and base Docker container images, enabled with EFA is available in the [aws-efa-nccl-baseami-pipeline](https://github.com/aws-samples/aws-efa-nccl-baseami-pipeline) project on GitHub. A [do-framework](https://bit.ly/do-framework) project for building a demo container image with EFA is included in subfolder [cuda-efa-nccl-tests](./cuda-efa-nccl-tests). Execute `./build.sh` to create a compatible container image, then `./push.sh` to upload the image to your private Elastic Container Registry on AWS.


## References

* Karpenter Documentation: [https://karpenter.sh/v0.10.1/](https://karpenter.sh/v0.10.1/)

* Provisioner CRD: [https://karpenter.sh/v0.10.0/provisioner/](https://karpenter.sh/v0.10.0/provisioner/)

* Scheduling: [https://karpenter.sh/v0.10.1/tasks/scheduling/](https://karpenter.sh/v0.10.1/tasks/scheduling/)

* Kaprenter Best Practices: [https://aws.github.io/aws-eks-best-practices/karpenter/](https://aws.github.io/aws-eks-best-practices/karpenter/)

* Elastic Fabric Adapter: [https://aws.amazon.com/hpc/efa/](https://aws.amazon.com/hpc/efa/)

* EFA - Supported instance types: [https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html#efa-instance-types](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html#efa-instance-types) 


