# QuickStart - NVIDIA Nemotron 3.5 Super VL 120B Self-managed Deployment on AWS

This is a quickstart walkthrough of running NVIDIA Nemotron 3.5 Super VL 120B-A12B (Early Access; BF16 and NVFP4 checkpoints) on Amazon [EKS](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html) or SageMaker [HyperPod EKS](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-eks.html), following the same pattern as the neighboring [nemotron/ultra](../ultra) deployment.

To simplify the deployment and testing we follow the principles of the [do-framework](https://bit.ly/do-framework) and provide automation as part of the [aws-do-eks](https://bit.ly/do-eks) project.

**Status (2026-10-19): 26 of the 34 fixed-concurrency cells in [test/RESULTS.md](test/RESULTS.md) are MEASURED live on an 8-node p5en.48xlarge (H200) EKS cluster with the Dynamo 1.4.0 platform — every `MANIFEST_TYPE` in `agg/` and `disagg/` except `disagg/epd` and the three PP>1 disaggregated shapes, at BF16 and NVFP4, each with `run.sh` as shipped, the chat + image smokes and `test-aiperf.sh`. The 8 remaining cells are NOT SUPPORTED on this software stack, with the exact upstream rejection recorded: `disagg/epd` (dynamo 1.5.0's encode worker only knows the LLaVA and Qwen-VL families) and `disagg/lws-2pp`, `disagg/lws-pp2`, `disagg/dgd-grove-pp2` (vLLM's NIXL connector refuses pipeline_parallel_size > 1 with a hybrid-Mamba KV layout, still true upstream through v0.32.0).**

**Update (2026-10-20, Dynamo 1.5.1 platform): 6 of those 8 cells are now MEASURED with opt-in builds of [`dynamo-vllm-efa/Dockerfile.ray`](dynamo-vllm-efa/Dockerfile.ray) on the same cluster — `--build-arg NIXL_PP_PATCH=1` (the vllm-project/vllm#53360 backport onto vLLM 0.28.0, both roles) for `disagg/lws-2pp`, `disagg/lws-pp2`; `--build-arg DYNAMO_EPD_NEMOTRON_PATCH=1` (adds the NemotronH Omni family to dynamo's encode worker) for `disagg/epd`; RESULTS.md footnotes ¹⁰²–¹⁰⁶. The stock image still rejects them exactly as recorded in footnotes 19, 26 and 42.**

**Update (2026-10-20, Grove/KAI gates on): the two `disagg/dgd-grove-pp2` cells — the last of the 8 — are MEASURED on the same cluster once the platform's Grove and KAI feature gates were switched on (`eks/deployment/grove`, the prerequisite the template header names); RESULTS.md footnotes BF16 ¹⁰⁸, NVFP4 ¹⁰⁹. With the gates off the 1.5.1 operator sets such a DGD to `no multinode orchestrator available` and creates no pods (footnote ¹⁰⁷). All 34 fixed-concurrency cells are now MEASURED.** The checkpoint facts below come from the checkpoint's own `config.json`.

## The model, from its config.json

* `architectures = ["NemotronH_Omni_Reasoning_V3"]`, `model_type = nemotron_h_omni` — a vision-language (Omni) wrapper around a `NemotronHForCausalLM` hybrid-Mamba MoE LLM. The vision tower is RADIO (ViT-H, hidden 1280, 32 layers, patch 16, `force_image_size` 512); `sound_config` is `null` in this checkpoint, so audio input is disabled by the model itself (image and video content types go through vLLM's `nano_nemotron_vl` implementation).
* LLM core: 88 layers (40 mamba / 40 moe / 8 attention), hidden 4096, 512 routed experts with 22 active per token + 1 shared expert, vocab 131072, `max_position_embeddings` 1048576, `mamba_ssm_cache_dtype float32`.
* MTP: `num_nextn_predict_layers = 1`, `mtp_layers_block_type = ["attention","moe"]` — the "mtp_boosted" in the EA directory name. The `SPEC_DECODE` toggle in the `.env` files exposes it (OFF by default, see below).
* BF16 checkpoint ≈ 249 GB (63 safetensors shards): **one 8-GPU H200/B200 node holds it with KV headroom** (~31 GB/GPU weights at TP8). The single-node shapes (`agg/deployment`, one node per role for `disagg/`) are therefore the primary matrix. The two-node LWS/PP2/wide-EP and Grove manifest types that `../ultra` needs to fit a 550B model are **also provided, for 1:1 `MANIFEST_TYPE` parity with the ultra tree**: each is ultra's template with only the Super delta applied, is **optional** here (the model does not need them); all of them were served and measured live on H200 on 2026-10-19 except the PP>1 disaggregated shapes, which stock vLLM 0.28.0 rejects (see [test/RESULTS.md](test/RESULTS.md)); those three shapes were measured on 2026-10-20 with the opt-in `dynamo-vllm-efa/Dockerfile.ray --build-arg NIXL_PP_PATCH=1` build (RESULTS.md footnotes ¹⁰²–¹⁰⁴, ¹⁰⁶, ¹⁰⁸, ¹⁰⁹; the Grove one also needs the platform's Grove + KAI gates on).

## Prerequisites

Identical to [nemotron/ultra](../ultra/README.md#prerequisites): the `aws-do-eks` shell (optional), a cluster with at least one 8-GPU H200/B200 node for aggregated (two for disaggregated P/D), the [EBS](https://github.com/aws-samples/aws-do-eks/tree/main/Container-Root/eks/deployment/csi/ebs) and [FSx](https://github.com/aws-samples/aws-do-eks/tree/main/Container-Root/eks/deployment/csi/fsx) CSI drivers with an `fsx-pvc` claim, the [NVIDIA device plugin](https://github.com/aws-samples/aws-do-eks/blob/main/Container-Root/eks/deployment/nvidia-device-plugin/), the [EFA device plugin](https://github.com/aws-samples/aws-do-eks/tree/main/Container-Root/eks/deployment/efa-device-plugin) (disagg, epd and every multinode `agg/` type), and the [NVIDIA Dynamo platform](https://github.com/aws-samples/aws-do-eks/tree/main/Container-Root/eks/deployment/nvidia-dynamo). Only for the optional multinode types ported from ultra: the [Leader Worker Set](https://github.com/aws-samples/aws-do-eks/tree/main/Container-Root/eks/deployment/lws) controller for the `lws*` types, and Grove + KAI from the [grove](https://github.com/aws-samples/aws-do-eks/tree/main/Container-Root/eks/deployment/grove) folder (Dynamo >= 1.4.0 platform) for the `dgd-grove*` types.

## Cluster types: traditional EKS / HyperPod EKS vs EKS Auto Mode

The same templates, `.env` knobs and scripts ran unchanged on two cluster classes: the 8-node p5en.48xlarge EKS cluster with managed node groups (the p5en grid in [test/RESULTS.md](test/RESULTS.md)) and an **EKS Auto Mode** cluster with four p5e.48xlarge Bottlerocket "EKS Auto, Nvidia" nodes on a capacity block plus a utility node (the p5e grid: 32 of 34 cells measured 2026-10-19/20, the two `disagg/epd` cells not run there). The templates apply to a SageMaker HyperPod EKS cluster the same way (instance-type labels carry the `ml.` prefix). The launch line that ran every p5e cell, from `agg/` or `disagg/`, with no template edit:

```bash
INSTANCE_TYPE_WORKER=p5e.48xlarge EFA_PER_WORKER=32 NAMESPACE=default INSTANCE_TYPE_FRONTEND=m7i.xlarge ./run.sh
```

What differs between the two classes and what this tree does about it (every row is a measured finding of that campaign, recorded in the "p5e / EKS Auto Mode notes" of [test/RESULTS.md](test/RESULTS.md)):

| Topic | Traditional EKS (managed node groups) / HyperPod EKS | EKS Auto Mode | Where it lives in this tree |
|---|---|---|---|
| Cluster config | eksctl manifests such as [eks-gpu-p5en-cbr.yaml](https://github.com/aws-samples/aws-do-eks/blob/main/wd/conf/eksctl/yaml/eks-gpu-p5en-cbr.yaml); HyperPod per its own tooling (instance-type labels carry the `ml.` prefix) | [eks-auto-mode-gpu-efa.yaml](https://github.com/aws-samples/aws-do-eks/blob/main/wd/conf/eksctl/yaml/eks-auto-mode-gpu-efa.yaml) plus the NodeClass + static NodePool manifests in [eks-auto-mode-gpu-efa/](https://github.com/aws-samples/aws-do-eks/tree/main/wd/conf/eksctl/yaml/eks-auto-mode-gpu-efa) (the capacity reservation id goes in the NodeClass); the p5e cluster that ran the campaign is [eks-auto-nemotron-super-vl.yaml](https://github.com/aws-samples/aws-do-eks/blob/main/wd/conf/eksctl/yaml/eks-auto-nemotron-super-vl.yaml) + [its folder](https://github.com/aws-samples/aws-do-eks/tree/main/wd/conf/eksctl/yaml/eks-auto-nemotron-super-vl) | — |
| GPU and EFA resources | the NVIDIA device plugin and the EFA device plugin are installed by you (prerequisites) | Auto Mode's "EKS Auto, Nvidia" Bottlerocket nodes expose `nvidia.com/gpu` and `vpc.amazonaws.com/efa` themselves: the kube-system EFA device-plugin DaemonSet installed per the folder's README scheduled on no node (DESIRED=0) and the nodes still advertised 32 EFA; nothing else to install | the templates request both resources either way |
| EFA per node | p5en.48xlarge 16 (`.env` default); p6-b200.48xlarge 8 | p5e.48xlarge 32 -> `EFA_PER_WORKER=32` | `.env` (`EFA_PER_WORKER`, table in the comments) |
| `/dev/gdrdrv` (the templates mount it as a `CharDevice` hostPath) | from the node AMI / your own DaemonSet | provided by [nvidia-drivers/gdrcopy-daemonset-bottlerocket.yaml](https://github.com/aws-samples/aws-do-eks/blob/main/Container-Root/eks/deployment/nvidia-drivers/gdrcopy-daemonset-bottlerocket.yaml) (+ `install-gdrcopy-bottlerocket.sh`); its `nodeSelector` names the NodeClass (`p5e-efa`), so adjust it to yours | — |
| GPU node taint | depends on your node group | `nvidia.com/gpu:NoSchedule` on every GPU node; every GPU container in the templates tolerates it | templates |
| Frontend placement | the *preferred* `INSTANCE_TYPE_FRONTEND` falls back to an existing node | Karpenter treats the preference as a provisioning hint and launches a node of that type for the frontend (a type that exists but has no room gets a new node too), consolidated away after teardown; pick a type that exists with room (the campaign used `m7i.xlarge`) or accept one extra small node per deployment | `.env` (`INSTANCE_TYPE_FRONTEND`) |
| Karpenter consolidation | n/a | the built-in `general-purpose` NodePool (`WhenEmptyOrUnderutilized`, 30 s) drained a utility node under a live frontend and two running aiperf clients; every frontend pod and the do-aiperf client now carry `karpenter.sh/do-not-disrupt: "true"` (inert without Karpenter); worker pods fill a GPU node and the GPU pools consolidate `Never` | templates, `test/aiperf-pod-run.sh` |
| Download pod | lands on any node | the former `nvidia.com/gpu.present` node pin is a GPU-operator/NFD label Auto Mode nodes do not carry (the pod stayed Pending) -> no pin by default, `HF_POD_NODE_SELECTOR` restores it | `download/hf-pod-run.sh` |
| Image pull | pull secret or node role, per your setup | a same-account private ECR pull worked with the node role, no pull secret | `.env` (`REGISTRY`/`IMAGE`/`TAG`) |
| EFA byte counters (the per-cell EFA proof) | read from host sysfs through a privileged `hostPath: /sys` pod per node (what [`eks/ops/efatop.sh`](https://github.com/aws-samples/aws-do-eks/blob/main/Container-Root/eks/ops/efatop.sh) does); the worker pod's own sysfs showed no `hw_counters` directory on the p5en pods either | same method; on the Bottlerocket nodes (kernel 6.12, efa module 3.1.0g) the container's sysfs has no `hw_counters` directory while the host has the full set | RESULTS.md "EFA proof" |
| FSx for Lustre | — | the FSx client itself rides EFA on these nodes (tens of GB of `rdma_read_bytes` during a weight load), so counters are read only around the benchmark windows; two checkpoints loading at once halve each other's rate on the 1.2 TiB volume | RESULTS.md p5e notes |
| Node health | — | Auto Mode surfaces GPU PCIe replays as node events (`AcceleratedHardwareReady ... NvidiaPCIeError`); read them alongside any failure | RESULTS.md p5e notes |

## Container image

The manifests default to the **stock NGC runtime** `nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.5.0-efa` (Dynamo 1.5.0 / vLLM 0.28.0 / EFA 1.50.0 / NIXL 1.3.2 with the LIBFABRIC plugin — contents verified by inspection on 2026-10-06). A golden-image recipe with base asserts and CVE remediation lives in [dynamo-vllm-efa](dynamo-vllm-efa); once that image is built and pushed, point `REGISTRY`/`IMAGE`/`TAG` in the `.env` files at it. This differs from `../ultra`, whose manifests default to its already-published golden image — no Super golden image exists yet, and defaulting to a nonexistent tag would make every pod `ImagePullBackOff`.

**Why vLLM 0.28.x needs an architecture alias:** the checkpoint names the bare architecture `NemotronH_Omni_Reasoning_V3`, which vLLM registers only from v0.29.0; vLLM 0.28.0 registers the equivalent `NemotronH_Super_Omni_Reasoning_V3` alias (same implementation). Every worker therefore passes `--hf-overrides '{"architectures":["NemotronH_Super_Omni_Reasoning_V3"]}'` (the `HF_OVERRIDE_ARCH` knob in `.env`). On a future base whose vLLM is ≥ 0.29 the override becomes optional. No NGC `vllm-runtime` tag published to date carries a vLLM that registers the bare name (checked 2026-10-06 across the tag list, including the dev tags).

## Download the model weights

Same pattern as [nemotron/ultra](../ultra/README.md#download-the-model-weights): an `iankoulski/do-hf` pod runs `hf download` onto the shared FSx volume, landing the checkpoint under `/shared/models/hf/<repo id>`, which is what the serving and test `.env` files default `MODEL_PATH` to. In the `aws-do-eks` shell, execute:

```bash
cd /eks/deployment/inference/agentic-ai/nemotron/super/download
./config.sh          # set HF_TOKEN and, if needed, MODEL_PRECISION (BF16 default, NVFP4)
./model-download.sh
```

The weights are downloaded from the public Hugging Face repo once the model is GA. The repo id in `download/.env` (`nvidia/NVIDIA-Nemotron-3.5-Super-VL-120B-A12B-{BF16,NVFP4}`) follows the Early-Access model-card names and ultra's naming; confirm it against the model card at GA — `MODEL_NAME` in `download/.env` is the one line to correct if the published id differs. Early-Access checkpoints already on an FSx volume are served by exporting `MODEL_PATH=<their directory>` before `./run.sh` (and before `./test-aiperf.sh`).

## Deploy the model

The folder decides whether prefill and decode are split; `MANIFEST_TYPE` decides the topology within that mode. `run.sh` renders `${MANIFEST_TYPE}.yaml-template` through `envsubst` and applies it; `./stop.sh` deletes it (plus a label sweep). `MODEL_VARIANT=NVFP4` switches the checkpoint without editing templates.

| Folder | `MANIFEST_TYPE` | Topology | Nodes | P/D split? |
|---|---|---|---|---|
| `agg/` | `deployment` | one worker, TP8/PP1 | 1 | no |
| `agg/` | `lws` | one worker, TP8/PP2 across 2 nodes — ported from ultra, optional here; measured live on H200, 2026-10-19 (test/RESULTS.md) | 2 | no |
| `agg/` | `lws-ep` | wide expert parallelism, DP`EP_DP_SIZE` x TP8 (EP16 by default); native `vllm serve`, no Dynamo frontend — ported from ultra, optional here; measured live on H200, 2026-10-19 (test/RESULTS.md) | 2 | no |
| `agg/` | `dgd` | `DynamoGraphDeployment`, one worker (needs the Dynamo operator) | 1 | no |
| `agg/` | `dgd-v1beta1` | the same deployment on `nvidia.com/v1beta1` — the CRD's **storage version** on a Dynamo 1.5.0 platform | 1 | no |
| `agg/` | `dgd-grove` | the `lws` engine shape (one engine, TP8 x PP`NODE_COUNT_PER_WORKER`) as a `v1beta1` DGD with `multinode.nodeCount`, Grove-rendered and gang-scheduled (needs Dynamo >= 1.4.0 + Grove/KAI) — ported from ultra, optional here; measured live on H200, 2026-10-19 (test/RESULTS.md) | `NODE_COUNT_PER_WORKER` (2) | no |
| `agg/` | `dgd-grove-ep` | the `lws-ep` shape (wide EP, DP`EP_DP_SIZE` x TP8) as a Grove-rendered DGD; the operator injects the DP coordination — ported from ultra, optional here; measured live on H200, 2026-10-19 (test/RESULTS.md) | `EP_DP_SIZE` (2) | no |
| `disagg/` | `deployment` | 1 prefill + 1 decode, TP8/PP1 each, KV over EFA via NIXL LIBFABRIC | 2 | yes |
| `disagg/` | `lws-2pp` | prefill TP8/PP2 + 2x decode TP8/PP1 — ported from ultra, optional here; **NOT SUPPORTED on the stock image** (its NIXL connector rejects PP>1 with hybrid KV, RESULTS.md footnote 26); **MEASURED 2026-10-20 with `dynamo-vllm-efa/Dockerfile.ray --build-arg NIXL_PP_PATCH=1`** (RESULTS.md footnotes BF16 ¹⁰³, NVFP4 ¹⁰⁶) | 4 | yes |
| `disagg/` | `lws-pp2` | symmetrical PP2: prefill AND decode each TP8/PP2 — ported from ultra, optional here; **NOT SUPPORTED on the stock image** (same NIXL gate, RESULTS.md footnote 42); **MEASURED 2026-10-20 with `dynamo-vllm-efa/Dockerfile.ray --build-arg NIXL_PP_PATCH=1`** (RESULTS.md footnotes BF16 ¹⁰², NVFP4 ¹⁰⁴) | 4 | yes |
| `disagg/` | `lws-ep` | wide expert parallelism **per role**: prefill DP`EP_DP_SIZE` x TP8 + decode DP`EP_DP_SIZE` x TP8 (EP16 each by default) — ported from ultra, optional here; measured live on H200, 2026-10-19 (test/RESULTS.md) | 2 x `EP_DP_SIZE` (4) | yes |
| `disagg/` | `epd` | dedicated vision-ENCODE worker + one aggregated PD worker (dynamo v1.5.0's `disagg_multimodal_e_pd.sh` shape) — **NOT SUPPORTED on the stock image** (dynamo 1.5.0's encode worker rejects this model family, RESULTS.md footnote 19); **MEASURED 2026-10-20 with `dynamo-vllm-efa/Dockerfile.ray --build-arg DYNAMO_EPD_NEMOTRON_PATCH=1`** (RESULTS.md footnotes BF16 ¹⁰¹, NVFP4 ¹⁰⁵) | 1 + encode | encode only |
| `disagg/` | `dgd` | `DynamoGraphDeployment` prefill + decode | 2 | yes |
| `disagg/` | `dgd-v1beta1` | the same on `nvidia.com/v1beta1` | 2 | yes |
| `disagg/` | `dgd-grove` | the `dgd-v1beta1` topology Grove-rendered and gang-scheduled as one PodGang (needs Dynamo >= 1.4.0 + Grove/KAI) — ported from ultra; measured live on H200, 2026-10-19 (test/RESULTS.md) | 2 | yes |
| `disagg/` | `dgd-grove-pp2` | the `lws-pp2` shape (symmetric PP2 per role) as a Grove-rendered DGD, both workers `multinode.nodeCount` — ported from ultra, optional here; **NOT SUPPORTED on the stock image** (same NIXL gate, RESULTS.md footnote 42); **MEASURED 2026-10-20 with `dynamo-vllm-efa/Dockerfile.ray --build-arg NIXL_PP_PATCH=1` on a platform with the Grove + KAI feature gates on** (RESULTS.md footnotes BF16 ¹⁰⁸, NVFP4 ¹⁰⁹; gates off = `no multinode orchestrator available`, footnote ¹⁰⁷) | 2 x `NODE_COUNT_PER_WORKER` (4) | yes |
| `disagg/` | `dgd-grove-ep` | the `lws-ep` shape (EP16 per role) as a Grove-rendered DGD; the operator injects the DP coordination — ported from ultra, optional here; measured live on H200, 2026-10-19 (test/RESULTS.md) | 2 x `EP_DP_SIZE` (4) | yes |

Multimodal serving facts baked into the templates, taken from dynamo v1.5.0's own launch scripts (`examples/backends/vllm/launch/agg_multimodal.sh`, `disagg_multimodal_p_d.sh`, `disagg_multimodal_e_pd.sh`): every worker runs `--enable-multimodal`; decode/PD workers add `--enable-mm-embeds`; the EPD encode worker runs `--disaggregation-mode encode` and the PD worker `--route-to-encoder --disaggregation-mode pd`; aggregated and EPD graphs set `DYN_REQUEST_PLANE=tcp` (base64 images exceed the NATS 1 MB payload limit — the P/D launch script does not set it, and neither do the P/D templates). The one exception is `agg/lws-ep`, which runs native `vllm serve` with no Dynamo runtime: vLLM 0.28 has no `--enable-multimodal` flag and nothing there reads `DYN_REQUEST_PLANE`, so that template carries neither and vLLM serves image content natively.

Aggregated:

```bash
cd /eks/deployment/inference/agentic-ai/nemotron/super/agg
./config.sh
./run.sh
```

Disaggregated:

```bash
cd /eks/deployment/inference/agentic-ai/nemotron/super/disagg
./config.sh
./run.sh
```

### MTP speculative decoding (`SPEC_DECODE`, off by default)

The checkpoint ships one MTP draft layer. vLLM 0.28.0 supports the family structurally (`nemotron_h_mtp` in `MTPModelTypes`, `models/nemotron_h_mtp.py` present); the canonical method name at that version is `mtp` (model-specific names are deprecation-folded into it), and with no `model` key the draft weights load from the serving checkpoint. `SPEC_DECODE=1 ./run.sh` adds `--speculative-config '{"method":"mtp","num_speculative_tokens":1}'`. **Whether the MTP path composes end-to-end with the Omni/VL wrapper has not been exercised on this checkpoint** — that is why the default is off, and why spec-decode results get their own rows in RESULTS.md.

### Context length and memory

`MAX_MODEL_LEN` (default 32768) and `GPU_MEM_UTIL` (default 0.90) are `.env` knobs rather than ultra's hardcoded 4096/0.97: the 550B memory squeeze does not apply at ~31 GB/GPU weights, so the context window is a real choice here (the checkpoint supports up to 1M positions). The defaults are deliberately modest scaffold values — nothing has been benchmarked.

## Test and benchmark the model

```bash
cd /eks/deployment/inference/agentic-ai/nemotron/super/test
./config.sh
./models-list.sh            # names of the hosted models
./models-health.sh          # deployment health + endpoints
./test-completions.sh       # one text request to /v1/completions
./test-chat-completions.sh  # one text request to /v1/chat/completions
./test-chat-image.sh        # ONE IMAGE PROMPT via image_url content (single-request vision check)
./test-aiperf.sh            # aiperf: the LLM text workload identical to ultra's (default)
AIPERF_WORKLOAD=vl ./test-aiperf.sh   # optional: the same profile with synthetic 512x512 images
./aiperf-sweep-run.sh       # the same text workload at concurrency 1,4,8,16,32,64
./aiperf-clean-tail.sh      # splits an aiperf export into its stalled tail and its steady state
```

The default `./test-aiperf.sh` is the **LLM text workload identical to ultra's** `test-aiperf.sh` (chat endpoint, ISL 1024 / OSL 512, concurrency 10, 100 requests, seed 42, the same excluded warmup phase, no image flags), so a Super row compares directly with the c=10 rows in [ultra's RESULTS.md](../ultra/test/RESULTS.md). It writes its artifacts and `run-meta.json` to `${MODEL_PATH}/aiperf/${DEPLOYMENT_TYPE}/${MANIFEST_TYPE}/${AIPERF_RUN_ID}` exactly as ultra does. `AIPERF_WORKLOAD=vl ./test-aiperf.sh` is the optional vision run: the same profile with synthetic images added to every request (`--image-width-mean/--image-height-mean`, aiperf ≥ 0.9.0; `AIPERF_IMAGE_WIDTH/HEIGHT` in `test/.env`, default 512 = the checkpoint's `force_image_size`), written under a `vl-` run id and marked `"workload": "vl"` in `run-meta.json`, so it can never be read as an LLM row. `./test-chat-image.sh` is the single-request vision check. `aiperf-sweep-run.sh`/`-logs.sh`/`-stop.sh`/`-summary.sh` and `aiperf-clean-tail.sh` are ultra's tools with only the model label changed; the sweep runs the text workload (there is no vision sweep). Results and the measurement discipline live in [test/RESULTS.md](test/RESULTS.md) — 26 measured c=10 rows (13 templates x BF16/NVFP4), 8 rows not supported on this stack with the exact rejection, two concurrency sweeps and two served-request smoke rows.

## Relationship to nemotron/ultra

This folder mirrors ultra's layout, scripts and conventions (`.env` + `envsubst` templates, `run.sh`/`stop.sh`, do-pods for download/test, a `dynamo-vllm-efa` golden-image recipe with a CVE gate). `download/` is ultra's Hugging Face download byte-for-byte except the model identifiers, and the default `test-aiperf.sh` benchmark is identical to ultra's, so the two trees' results compare directly; VL benchmarking is opt-in (`AIPERF_WORKLOAD=vl`). Deliberate differences, each stated where it applies: stock-NGC default image, the `--hf-overrides` architecture alias, multimodal flags + TCP request plane, the EPD template, `test-chat-image.sh`, parameterized `MAX_MODEL_LEN`/`GPU_MEM_UTIL`, `SPEC_DECODE`, pod-network disagg (no host networking anywhere in this tree), no `--moe-backend` pin (ultra's encodes a vLLM-0.26 measurement that has not been reproduced on 0.28/this model), and no `kv-lease-check.sh` (ultra-specific). The multinode LWS/PP2/wide-EP and Grove manifest types are carried from ultra for `MANIFEST_TYPE` parity — each is ultra's template with only the Super delta applied, optional here (one node holds the model); all but the PP>1 disaggregated shapes were measured live on H200 on 2026-10-19 — so the two trees render the same set of topologies.
