# QuickStart - NVIDIA Nemotron 3 Ultra 550B Self-managed Deployment on AWS

This is a quickstart walkthrough of running [NVIDIA Nemotron 3 Ultra 550B A55B BF16](https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Ultra-550B-A55B-BF16) on Amazon [EKS](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html) or SageMaker [HyperPod EKS](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-eks.html)

To simplify the deployment and testing we follow the principles of the [do-framework](https://bit.ly/do-framework) and provide automation as part of the [aws-do-eks](https://bit.ly/do-eks) project.

## Prerequisites

### 1. `aws-do-eks` shell

It is recommended (though optional) to use the `aws-do-eks` shell when deploying the model. 
To run this shell, either build and run the [aws-do-eks](https://bit.ly/do-eks) project, or run the public [container](https://bit.ly/aws-do-eks-container).
The root folder in the container shell `/` corresponds to the `Container-Root` folder in the project.

### 2. Cluster with H200 or B200 GPUs
A minimum of 8 H200 or B200 GPUs is required to run a single aggregated instance of the model.
Due to the model size, to run on only 8 GPUs, some settings need to be enforced, which cause sub-optimal latency and throughput. For better performance, a single model instance can be served on 16 GPUs.

Capacity can be reserved via [EC2 ODCR](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-capacity-reservations.html) or [ML Capacity Block](https://aws.amazon.com/ec2/capacityblocks/) on EKS or [Flexible Traing Plan](https://docs.aws.amazon.com/sagemaker/latest/dg/reserve-capacity-with-training-plans.html) on HyperPod EKS.

#### 2a. Amazon EKS cluster
The [aws-do-eks](https://bit.ly/do-eks) project contains example [eksctl](https://eksctl.io) cluster manifests for [p5en](https://github.com/aws-samples/aws-do-eks/blob/main/wd/conf/eksctl/yaml/eks-gpu-p5en-cbr.yaml) and [p6-b200](https://github.com/aws-samples/aws-do-eks/blob/main/wd/conf/eksctl/yaml/eks-gpu-p6-b200-cbr.yaml). It also contains an example [terraform](https://developer.hashicorp.com/terraform) template for [p6-b200](https://github.com/aws-samples/aws-do-eks/tree/main/wd/conf/terraform/eks-p6-b200)

#### 2b. SageMaker HyperPod EKS cluster
The [aws-do-hyperpod](https://bit.ly/aws-do-hyperpod) project, the [hyperpod-eks](https://bit.ly/smhp-eks-workshop) workshop, and the SageMaker HyperPod EKS [documentation](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-eks-operate-console-ui-create-cluster.html) are good resources to help with creating a HyperPod EKS cluster.

### 3. EBS and FSx CSI drivers
Deploy the [EBS](https://github.com/aws-samples/aws-do-eks/tree/main/Container-Root/eks/deployment/csi/ebs) and [FSx](https://github.com/aws-samples/aws-do-eks/tree/main/Container-Root/eks/deployment/csi/fsx) CSI drivers to your cluster.
Use the `./sc-set.sh` script from the [csi](https://github.com/aws-samples/aws-do-eks/tree/main/Container-Root/eks/deployment/csi) folder to set your default storage class to `gp2`. Create an FSxL PVC called `fsx-pvc` by applying the `fsx-pvc-dynamic.yaml` manifest from the [fsx](https://github.com/aws-samples/aws-do-eks/blob/main/Container-Root/eks/deployment/csi/fsx) folder.

### 4. NVIDIA GPU Device Plugin
The plugin can be deployed from the [nvidia-device-plugin](https://github.com/aws-samples/aws-do-eks/blob/main/Container-Root/eks/deployment/nvidia-device-plugin/) folder, or using your preferred method.

### 5. EFA Device Plugin
The plugin can be deployed from the [efa-device-plugin](https://github.com/aws-samples/aws-do-eks/tree/main/Container-Root/eks/deployment/efa-device-plugin) folder, or using your preferred method.

### 6. Leader Worker Set
You can deploy the Leader Worker Set Controller and CRD using the [lws](https://github.com/aws-samples/aws-do-eks/tree/main/Container-Root/eks/deployment/lws) folder, or another method.

### 7. NVIDIA Dynamo Platform
Deploy [NVIDIA Dynamo] by running the `./deploy.sh` script in the [nvidia-dynamo](https://github.com/aws-samples/aws-do-eks/tree/main/Container-Root/eks/deployment/nvidia-dynamo) folder.


## Download the model weights

In the `aws-do-eks` shell, execute:

```bash
cd /eks/deployment/inference/agentic-ai/nemotron/ultra/download
./config.sh
./model-download.sh
```

## Deploy the model

The model can be deployed in aggregated or disaggregated mode. In aggregated mode the prefill and decode work in any inference operation is performed by a single worker. In disaggregated mode the prefill and decode operations are done by different workers which are deployed on different nodes and can be scaled independently.

### Aggregated mode

In the `aws-do-eks` shell, execute:

```bash
cd /eks/deployment/inference/agentic-ai/nemotron/ultra/agg
./config.sh
./run.sh
```

### Disaggregated mode

Disaggregated mode on EFA requires a patched version of the `nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.2.0-efa` container. A pre-built container image is available at `public.ecr.aws/hpc-cloud/dynamo-vllm-efa:disagg-1.2.0`. If you prefer to build your own image, use the [dynamo-vllm-efa](https://github.com/aws-samples/aws-do-eks/tree/main/Container-Root/eks/deployment/inference/agentic-ai/nemotron/ultra/disagg/dynamo-vllm-efa) folder. The example here is configured to use the pre-built image.

In the `aws-do-eks` shell, execute:

```bash
cd /eks/deployment/inference/agentic-ai/nemotron/ultra/disagg
./config.sh
./run.sh
```

## Test and benchmark the model

In the `aws-do-eks` shell, execute:

```bash
cd /eks/deployment/inference/agentic-ai/nemotron/ultra/test
./config.sh
```

Then run any or all of the following tests:

```bash
./models-list.sh
./models-health.sh
./test-completions.sh
./test-chat-completions.sh
./test-aiperf.sh
./aiperf-sweep-run.sh
```

* `./models-list.sh` - shows the names of the hosted models
* `./models-health.sh` - shows the health of the model deployment and lists the endpoints
* `./test-completions.sh` - tests a single request to the /v1/completions API
* `./test-chat-completions.sh` - tests a single request to the /v1/chat/completions API
* `./test-aiperf.sh` - runs aiperf against the model endpoint, reports benchmark results
* `./aiperf-sweep-run.sh` - runs a sweep of aiperf tests with concurrency 1,4,8,16,32,64 to explore scalability

