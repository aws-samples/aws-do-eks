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

change config values in .env

change eks.conf
    export CONFIG=yaml
    export EKS_YAML=./eks-dl1.yaml

change eks-dl1.yaml
    change or create ssh key:
        publicKeyName: DL1_Key

### 0.2.3. Build and run aws-do-eks container

```
./build.sh
./run.sh
./status.sh
./exec.sh
```

### 0.2.4. Create cluster

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
** TODO: Improve deploy script to detect existing efs without mounting target in the eks cluster subnets.
         Consequently remove explicit call to ./efs-create.sh.

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
cd /eks/deployment/kubeflow/mpi-operator
./deploy.sh
```

### 0.2.7. Configure distributed training

```
cd /eks/deployment/distributed-training/pytorch/habana/deepspeed-bert
```
adjust settings

Set the number of desired workers in 
deepspeed-bert.yaml.template

Set the training hyperparametrs (LR, batch sizes, etc.) in
scripts/deepspeed_config_bert_1.5b.json
scripts/launch_train.sh

## 1. Build and push deep learning container

```
./1-1-container-build.sh
./1-2-container-push.sh
```

## 2. Download data

```
./2-1-data-download.sh
./2-2-data-status.sh
./2-3-data-log.sh
```

Downloading and pre-processing the data takes a long time (could be more than 24 hours)

## 3. Distributed training

### 3.1. Scale up DL1 nodes

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

```
./3-1-training-launch.sh
watch ./3-2-training-status.sh
# When pods are running, check logs:
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

