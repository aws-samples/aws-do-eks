# Torch-elastic samples

The torch-elastic example here uses the a Kubernetes elasticjob manifest to demonstrate distributed training of resnet18 on a small imagenet dataset. 

The public container torchelastic/examples:0.2.0 includes a fixed version of pytorch, cuda drivers, and nccl libraries. These must be compatible with the version of CUDA and NCCL running on the Kubernetes nodes where the job workers are spawned. The version of these drivers on your nodes depends on the AMI that was used to provision them.

If your imagenet example does not work out of the box, it is possible that your nodes do not have the correct drivers. There are two options to consider:

1. Recommended for production: Build a custom AMI and use it to create a new cluster, or a new node group in your existing cluster.
The following sampl open source repository contains packer scripts for building a cusom EKS AMI:
[https://github.com/aws-samples/aws-efa-nccl-baseami-pipeline](https://github.com/aws-samples/aws-efa-nccl-baseami-pipeline)
This repo also contains a Dockerfile which shows how to build a corresponding container image with matching drivers.
In addition the AMI and Docker image contain drivers to enable AWS Elastic Fabric Adapter on supported instance types (p3dn.24xlarge and p4d.24xlarge) and a setup to enable GPU metrics.
Your custom Docker image will need to be pushed to a registry such as ECR where the Kubernetes cluster will be able to pull it from.

2. Acceptable for development: Apply a privileged daemonset to install proper drivers on your existing EKS nodes.
An example daemonset which installs NVIDIA CUDA drivers and FabricManager 470 on Amazon Linux 2 (AL2) nodes is provided in the [deployments/nvidia-drivers](/Container-Root/eks/deployment/nvidia-drivers) folder of this repo. This is approach may be acceptable for use in a development environment, however it should never be used in production due to the fact that it requires privileged pods, which circumvent the security constraints of your Kubernetes cluster.


