# Torch-elastic samples

The pytorch examples here use the a Kubernetes elasticjob manifest to demonstrate distributed training of various [torchvision](https://pytorch.org/vision/stable/models.html) models on the imagenet dataset.

These examples assume that the data has already been copied to either EFS or FSx filesystem using steps described under [csi](/Container-Root/eks/deployment/csi) folder.

Before running any training jobs, we need to deploy torch elastic controler and also deploy a pod running etcd server. We can do this by simply running the script `deploy.sh` in this folder.
