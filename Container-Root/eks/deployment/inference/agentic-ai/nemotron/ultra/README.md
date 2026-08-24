# QuickStart - NVIDIA Nemotron 3 Ultra 550B Self-managed Deployment on AWS

This is a quickstart walkthrough of running [NVIDIA Nemotron 3 Ultra 550B A55B BF16](https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Ultra-550B-A55B-BF16) and [NVIDIA Nemotron 3 Ultra 550B A55B NVFP4](https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Ultra-550B-A55B-NVFP4) on Amazon [EKS](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html) or SageMaker [HyperPod EKS](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-eks.html).

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
The [aws-do-eks](https://bit.ly/do-eks) project contains example [eksctl](https://eksctl.io) cluster manifests for [p5en](https://github.com/aws-samples/aws-do-eks/blob/main/wd/conf/eksctl/yaml/eks-gpu-p5en-cbr.yaml) and [p6-b200](https://github.com/aws-samples/aws-do-eks/blob/main/wd/conf/eksctl/yaml/eks-gpu-p6-b200-cbr.yaml). It also contains an example [terraform](https://developer.hashicorp.com/terraform) template for [p6-b200](https://github.com/aws-samples/aws-do-eks/tree/main/wd/conf/terraform/eks-p6-b200).

#### 2b. SageMaker HyperPod EKS cluster
The [aws-do-hyperpod](https://bit.ly/aws-do-hyperpod) project, the [hyperpod-eks](https://bit.ly/smhp-eks-workshop) workshop, and the SageMaker HyperPod EKS [documentation](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-eks-operate-console-ui-create-cluster.html) are good resources to help with creating a HyperPod EKS cluster. A HyperPod EKS cluster can also be created easilry from the [AWS Console](https://us-east-1.console.aws.amazon.com/sagemaker/home?region=us-east-1#/cluster-management/create-hp-eks).

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

The model can be deployed in aggregated or disaggregated mode. In aggregated mode the prefill and decode work in any inference operation is performed by a single worker. In disaggregated mode the prefill and decode operations are done by different workers which are deployed on different nodes and can be scaled independently. The model can be deployed using deployment manifests when running one instance of the model on one node, or using a [LeaderWorkerSet](https://github.com/kubernetes-sigs/lws) manifest when running a model instance distributed between two nodes. Additionally, a DynamoGraphDeployment manifest can be used to deploy the model in either aggregated or disaggregated mode with the help of the Dynamo operator.  Set `MANIFEST_TYPE` in the corresponding `.env` file per your preference.

The folder decides whether prefill and decode are split; `MANIFEST_TYPE` decides the topology within that mode. The table below describes all available manifest and topology options:

| Folder | `MANIFEST_TYPE` | Topology | Nodes | P/D split? |
|---|---|---|---|---|
| `agg/` | `deployment` | one worker, TP8/PP1 | 1 | no |
| `agg/` | `lws` | one worker, TP8/PP2 across 2 nodes | 2 | no |
| `agg/` | `lws-ep` | wide expert parallelism, DP`EP_DP_SIZE` x TP8 (EP16 by default) | 2 | no |
| `agg/` | `dgd` | `DynamoGraphDeployment`, one worker (needs the Dynamo operator) | 1 | no |
| `agg/` | `dgd-v1beta1` | the same deployment on the `nvidia.com/v1beta1` API instead of the deprecated `v1alpha1` | 1 | no |
| `agg/` | `dgd-grove` | the `lws` engine shape (one engine, TP8 x PP`NODE_COUNT_PER_WORKER`) as a `v1beta1` DGD with `multinode.nodeCount`, Grove-rendered and gang-scheduled (needs Dynamo >= 1.4.0 + Grove/KAI) | `NODE_COUNT_PER_WORKER` (2) | no |
| `agg/` | `dgd-grove-ep` | the `lws-ep` shape (wide EP, DP`EP_DP_SIZE` x TP8) as a Grove-rendered DGD; the operator injects the DP coordination — unproven pending live smoke, see the template header | `EP_DP_SIZE` (2) | no |
| `disagg/` | `deployment` | 1 prefill + 1 decode, TP8/PP1 each | 2 | yes |
| `disagg/` | `lws-2pp` | prefill TP8/PP2 + 2x decode TP8/PP1 | 4 | yes |
| `disagg/` | `lws-pp2` | symmetrical PP2: prefill AND decode each TP8/PP2 | 4 | yes |
| `disagg/` | `lws-ep` | wide expert parallelism **per role**: prefill DP`EP_DP_SIZE` x TP8 + decode DP`EP_DP_SIZE` x TP8 (EP16 each by default) | 2 x `EP_DP_SIZE` (4) | yes |
| `disagg/` | `dgd` | `DynamoGraphDeployment` prefill + decode (needs the Dynamo operator) | 2 | yes |
| `disagg/` | `dgd-v1beta1` | the same deployment on the `nvidia.com/v1beta1` API instead of the deprecated `v1alpha1` | 2 | yes |
| `disagg/` | `dgd-grove` | the `dgd-v1beta1` topology Grove-rendered and gang-scheduled as one PodGang (needs Dynamo >= 1.4.0 + Grove/KAI) | 2 | yes |
| `disagg/` | `dgd-grove-pp2` | the `lws-pp2` shape (symmetric PP2 per role) as a Grove-rendered DGD, both workers `multinode.nodeCount` — requires the `:1.4.0-patched` image (stock vLLM 0.26 refuses PP>1 + hybrid-KV); unvalidated through the operator path, see the template header | 2 x `NODE_COUNT_PER_WORKER` (4) | yes |
| `disagg/` | `dgd-grove-ep` | the `lws-ep` shape (EP16 per role) as a Grove-rendered DGD; the operator injects the DP coordination — unproven pending live smoke, see the template header | 2 x `EP_DP_SIZE` (4) | yes |

`MANIFEST_TYPE` names the template file directly. For example, if MANIFEST_TYPE=dgd, then `run.sh` replaces all variables in dgd.yaml-template with values from .env, producing `dgd.yaml`, then executes `kubectl apply -f ./dgd.yaml`. The `./stop.sh` script executes `kubectl delete -f ./dgd.yaml` correspondingly. 

#### The `DynamoGraphDeployment` deprecation warning

Applying either `dgd` template on a Dynamo platform 1.3.x operator prints:

```
Warning: nvidia.com/v1alpha1 DynamoGraphDeployment is deprecated; use nvidia.com/v1beta1 DynamoGraphDeployment
```

This is just a warning. `v1alpha1` is still the CRD's **storage** version on 1.3.x, so the object is stored exactly as written; the warning is the API server reading the CRD's `deprecationWarning` field. You can confirm on your own cluster with:

```bash
kubectl get crd dynamographdeployments.nvidia.com \
  -o jsonpath='{range .spec.versions[*]}{.name}{" served="}{.served}{" storage="}{.storage}{"\n"}{end}'
```

`agg/dgd-v1beta1` and `disagg/dgd-v1beta1` are the same two deployments expressed on the new API, for when you want the warning gone or want to be ready for the release that flips the storage version. Each is a pure API port -- image, flags, env, resources, probes, node placement and (for disagg) `--kv-transfer-config` are byte-identical to its `dgd` sibling. What the new schema changes: `spec.services{}` becomes `spec.components[]`, `spec.envs` becomes `spec.env`, `componentType: worker` + `subComponentType: prefill|decode` becomes `type: prefill|decode`, `extraPodSpec.mainContainer` becomes a normal pod template whose container is named `main`, and `spec.pvcs` is gone in favour of an ordinary `persistentVolumeClaim` volume.

The `dgd` templates are the default and stay on `v1alpha1` deliberately: nothing about the warning requires action. If you'd like to switch,deploy `dgd-v1beta1` once, confirm the pods come up, then flip your default.

Both API versions depend on the operator pod being healthy. The `DynamoGraphDeployment` admission webhooks are registered with `failurePolicy: Fail` and the CRD's conversion strategy is `Webhook`: with the controller-manager not Ready, a `v1alpha1` apply is rejected by admission, and a `v1beta1` apply or even `kubectl get dgd` additionally fails conversion with `conversion webhook ... no endpoints available`.

```bash
kubectl -n dynamo-system get pods
kubectl -n dynamo-system get endpoints dynamo-platform-dynamo-operator-webhook-service
```

Every `disagg/` template carries `--kv-transfer-config` with `NixlConnector` and moves the KV cache over EFA; no `agg/` template does. **`lws-ep` exists in both folders under the same name, and they are different topologies** -- the folder is the discriminator, so read it as "wide expert parallelism, in this folder's mode". `agg/lws-ep` is **aggregated** wide-EP: it exercises EFA heavily (the MoE all-to-all is NCCL across nodes on every token) but it does not disaggregate.`disagg/lws-ep` is the disaggregated one, at twice the node count.

Expert parallelism *with* a prefill/decode split is a real configuration, and it is `lws-ep` under `disagg/`: EP and disagg are orthogonal, so each role gets its own EP group -- its own DP coordinator, and `--enable-expert-parallel` plus `--disaggregation-mode` on both. Two fabrics are then in play at once, KV prefill->decode per **request** over NIXL/EFA and the MoE expert all-to-all per **token** over NCCL/EFA.

### Aggregated mode

In the `aws-do-eks` shell, execute:

```bash
cd /eks/deployment/inference/agentic-ai/nemotron/ultra/agg
./config.sh
./run.sh
```

### Disaggregated mode

On Dynamo 1.4.0 / vLLM 0.26 (`nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.4.0-efa`), disaggregated mode on EFA no longer requires vLLM patches at PP1 — the stock NIXL connector transfers hybrid-Mamba KV correctly (verified live on 2x p5en.48xlarge, 2026-08-20). The manifests default to `public.ecr.aws/hpc-cloud/dynamo-vllm-efa:1.4.0-patched`, a thin overlay on that base adding ray (multi-node pipeline parallel), the NVFP4 cubin-dir fix, and CVE remediation; build it yourself with the [dynamo-vllm-efa](https://github.com/aws-samples/aws-do-eks/tree/main/Container-Root/eks/deployment/inference/agentic-ai/nemotron/ultra/dynamo-vllm-efa) folder. PP>1 disaggregation (pipeline-parallel prefill) is enabled by the `patches/` layer in the same folder — the 0.26-era successor of vLLM PR#48263, verified on 4x B200 with 550B (PP2 prefill -> PP1 decode, byte-parity KV reads from both stages). On a Dynamo 1.3.1 platform use the previous image `public.ecr.aws/hpc-cloud/dynamo-vllm-efa:1.3.1-patched` (recipe preserved in the folder's git history).

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
./aiperf-clean-tail.sh
./kv-lease-check.sh
```

* `./models-list.sh` - shows the names of the hosted models
* `./models-health.sh` - shows the health of the model deployment and lists the endpoints
* `./test-completions.sh` - tests a single request to the /v1/completions API
* `./test-chat-completions.sh` - tests a single request to the /v1/chat/completions API
* `./test-aiperf.sh` - runs aiperf against the model endpoint, reports benchmark results
* `./aiperf-sweep-run.sh` - runs a sweep of aiperf tests with concurrency 1,4,8,16,32,64 to explore scalability
* `./aiperf-clean-tail.sh` - splits an aiperf export into its stalled tail and its steady state
* `./kv-lease-check.sh` - checks a disagg run for requests served on KV blocks the prefill side had already freed

Measured results from these tests — a full template × precision matrix at fixed concurrency, two
agg-vs-disagg concurrency sweeps at equal GPU count, and a PP>1 output-correctness gate, collected
on a 4-node B200 cluster on 2026-08-14..18 — are recorded in [test/RESULTS.md](test/RESULTS.md).

`test-aiperf.sh` writes its artifacts to
`${MODEL_PATH}/aiperf/${DEPLOYMENT_TYPE}/${MANIFEST_TYPE}/${AIPERF_RUN_ID}` and prints the path
before it starts. `AIPERF_RUN_ID` defaults to a UTC timestamp, so comparing topologies or rerunning
one of them keeps every report -- set `MANIFEST_TYPE` in `test/.env` to match the deployed topology
so the folder is labelled correctly, and set `AIPERF_RUN_ID` to name a run (`AIPERF_RUN_ID=cold`).

Because that label is asserted rather than checked, `test-aiperf.sh` also writes a `run-meta.json`
next to the report recording what actually served it.

`aiperf-sweep-run.sh` runs the same workload as `test-aiperf.sh` at six concurrencies instead of
one, so its phases are comparable with the fixed-concurrency reports rather than being a separate
experiment. Same aiperf (0.9.0), same ISL/OSL (`--synthetic-input-tokens-mean 1024
--synthetic-input-tokens-stddev 0 --output-tokens-mean 512`), same `--extra-inputs ignore_eos:true`
so the output length is pinned, same `--transport http` and `--random-seed 42`; only
`--concurrency`, `--request-count` and `--warmup-request-count` change per phase. It publishes its
bundle to `${MODEL_PATH}/aiperf/${DEPLOYMENT_TYPE}/${MANIFEST_TYPE}/sweep-<UTC timestamp>` on the
shared volume when it finishes, and warns with a `kubectl cp` fallback rather than failing if that
copy does not land.

Read a disagg report through `./aiperf-clean-tail.sh <artifact-dir>/profile_export.jsonl` before
quoting a TTFT mean or an upper percentile. 
Always state the cutoff a count was taken at; the count is a function of the
cut, so two counts taken at different cuts are not a comparison. The script reports the two
populations separately and how much wall clock the stall cost. The unconditional warmup phase in
`test-aiperf.sh` prevents the class of stall that is confined to the opening concurrency wave; this
script is for reading the class that recurs mid-run, which a warmup cannot remove.

Run `./kv-lease-check.sh` after any disagg benchmark. In vLLM's NixlConnector the prefill side holds
each request's KV blocks under a lease and frees them when it elapses; a later read by the decode
worker is then only logged, never failed, so the request still returns 200 on blocks that are gone.
A live 3-Pod `disagg/dgd` run on 2026-08-16 did exactly that on 8 of 42 completed requests, 21-32s
after the stock 30s lease expired with zero reads. `KV_LEASE_DURATION` in `disagg/.env` raises the
lease (default 300s here) and the script exits non-zero when a lease expires unread..
