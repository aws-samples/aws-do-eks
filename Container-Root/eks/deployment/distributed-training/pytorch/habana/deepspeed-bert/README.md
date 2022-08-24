# DeepSpeed Bert 1.5b

## 0. Prerequisites

## 0.1. Configure AWS account access (Optional)

```
aws configure --profile ${AWS_PROFILE:-default}
```

## 0.2. Setup EKS cluster with DL1 instances

### 0.2.1. Clone aws-do-eks

```
git clone https://github.com/aws-samples/aws-do-eks.git
```

### 0.2.2. Configure cluster

Change the configuration in `eks.conf` to use yaml and set it to `eks-dl1.yaml`:
```
export CONFIG=yaml
export EKS_YAML=./eks-dl1.yaml
```

The file `eks-dl1.yaml` describes the node groups that will be created for the cluster and what EC2 key pair will be used in the instances. [Create a EC2 key pair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) or use one that you already have.

```yaml
publicKeyName: DL1_Key
```

### 0.2.3. Build and run aws-do-eks container

```
./build.sh
./run.sh
./status.sh
./exec.sh
```

### 0.2.4. Create cluster
Within the aws-do-eks container run:
```
echo "AWS_PROFILE=$AWS_PROFILE"
./eks-create.sh
```
This operation could take up to ~30min

### 0.2.5. Verify cluster setup

```
kubectl get nodes
```

### 0.2.5. Create shared EFS persistent volume

```
cd /eks/deployment/csi/efs/
./efs-create.sh
./deploy.sh
kubectl apply -f ./efs-pvc.yaml
```


### 0.2.6. Deploy plugins and operators

#### 0.2.6.1. Deploy Habana device plugin
```
cd /eks/deployment/habana-device-plugin
 ./deploy.sh
```

#### 0.2.6.2. Deploy EFA device plugin
```
cd /eks/deployment/efa-device-plugin
 ./deploy.sh
```

#### 0.2.6.3. Deploy Kubeflow mpi-operator
```
cd /eks/deployment/kubeflow/mpi-operator
./deploy.sh
```

### 0.2.7. Configure distributed training

```
cd /eks/deployment/distributed-training/pytorch/habana/deepspeed-bert
```
In the file `deepspeed-bert.yaml.template`, set the number of desired workers:

```yaml
    Worker:
      replicas: 2
```
In this case, the number of workers is the number of instances (nodes) you want to run the training.

#### Adjust training hyperparameters (Optional)

You can change the DeepSpeed parameters (as `train_batch_size` and `train_micro_batch_size_per_gpu`) in the file `scripts/deepspeed_config_bert_1.5b.json`

Other training parameters can be adjusted in the launch script `scripts/launch_train.sh`:

```
MAX_SEQ_LENGTH=128
MAX_STEPS=155000
LR=0.0015
```

## 1. Build and push deep learning container

```
./1-1-container-build.sh
./1-2-container-push.sh
```

## 2. Download data

Before running the training, you first have to download and pre-process the dataset:

```
./2-1-data-download.sh
./2-2-data-status.sh
./2-3-data-log.sh
```

Downloading and pre-processing the data takes a long time (could be more than 24 hours)

## 3. Distributed training

### 3.1. Scale up DL1 nodes

Once you have the data downloaded and pre-processed, you can prepare the enviroment for the training task.
Here choose the same number of workers you have set in the `deepspeed-bert.yaml.template` file.
```
eksctl scale nodegroup --cluster=do-eks --nodes=2 --name=dl1
```

Wait until nodes become available. Continuously check if nodes are ready:

```
watch kubectl get nodes
```

```
Example:
NAME                            STATUS   ROLES    AGE     VERSION
ip-192-168-70-74.ec2.internal   Ready    <none>   1m22s   v1.21.12-eks-5308cf7
ip-192-168-83-89.ec2.internal   Ready    <none>   1m23s   v1.21.12-eks-5308cf7
```

### 3.2. Run training

After the nodes are ready, you can run the training task:

```
./3-1-training-launch.sh
watch ./3-2-training-status.sh
```

When pods are running, you can check logs:
```
./3-3-training-logs.sh
```

### 3.3. Explore

Optionally exec into launcher pod:
``` 
./3-4-training-exec.sh
```

Optionally, explore tensor board:
```
kubectl apply -f ./tensorboard.yaml 
```

### 3.3. Stop training
```
./3-5-training-delete.sh
```

### 3.4. Scale down DL1 nodes
```
eksctl scale nodegroup --cluster=do-eks --nodes=0 --name=dl1
```

# 4. Clean up

## 4.1. Delete shared EFS volume
```
kubectl delete -f ./efs-get-data.yaml
cd /eks/deployment/csi/efs
kubectl delete -f ./efs-pvc.yaml
./delete.sh
```

## 4.2. Delete cluster
```
cd /eks
./eks-delete.sh
```


