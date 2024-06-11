# Out of the box PyTorch FSDP distributed training on Amazon EKS

This example follows the principles of the [do-framework](https://bit.ly/do-framework) to provide a simple deployment of fully-sharded data parallel model training on [Amazon EKS](https://aws.amazon.com/eks). Included here are step-by-step instructions for how to run an FSDP training/fine-tuning job for NanoGPT or Llama2 models.

## Prerequisites

* [git](https://git-scm.com/downloads) is needed to clone the project
* [Docker](https://docs.docker.com/get-docker/) is needed to build the project
* [AWS account](https://console.aws.amazon.com)
* [Amazon EKS](https://aws.amazon.com/eks) cluster. If you need to create a cluster, you may use the [aws-do-eks](https://bit.ly/do-eks) project, or any other method for management of EKS infrastructure. 

## Clone

The FSDP examples are included in the [aws-do-eks](https://bit.ly/do-eks) project.

```bash
git clone https://github.com/aws-samples/aws-do-eks
```

## Set working directory

The examples are locateed in the `distributed-training` directory under `eks/deployment.`

```bash
cd Container-Root/eks/deployment/distributed-training/pytorch/pytorchjob/fsdp
```

or within the `aws-do-eks` container

```bash
cd /aws-do-eks/Container-Root/eks/deployment/distributed-training/pytorch/pytorchjob/fsdp
```

## Configure

All configuration is centralized in the .env file. Included is support for two model families: [NanoGPT](https://github.com/lessw2020/fsdp_llm), and [Llama2](https://github.com/facebookresearch/llama-recipes). Configure which model to use and related settings by editing the `.env` file.

```bash
./config.sh
```

## Deploy

In order for a PyTorchJob to run on the cluster, it is required to have the kubeflow training-operator as well as etcd deployed. A one-time execution of the `deploy.sh` script ensures both of these deployments are present. If needed, you may use the `remove.sh` script to reverse the deployment.

```bash
./deploy.sh
```

## Build

Build a container image for the configured model and settings.

```bash
./build.sh
```

## Push

Push the container image to your registry

```bash
./push.sh
```

## Run FSDP job

To create a PyTorchJob and run it on your cluster using the container you built, simply execute the `./run.sh` script.

```bash
./run.sh
```

## Check status

At any point you can check the status of your FSDP job.

```bash
./status.sh
```

## See logs

If you'd like to see your job logs, use the `logs.sh` script

```bash
./logs.sh
```

## Stop FSDP job

To stop a running or remove a completed job, execute the `stop.sh` script.
Before running a new job, the previous one needs to be removed. 

```
./stop.sh
```

# References

* [Amazon EKS](https://aws.amazon.com/eks)
* [Docker](https://www.docker.com)
* [Kubeflow training-operator](https://github.com/kubeflow/training-operator)
* [Etcd](https://etcd.io/)
* [FSDP LLM repo](https://github.com/lessw2020/fsdp_llm)
* [NanoGPT](https://nano-gpt.com/)
* [Llama Recipes](https://github.com/facebookresearch/llama-recipes)
