# QuickStart - NVIDIA Nemotron 3.5 Super VL 120B Self-managed Deployment on AWS

This is a quickstart walkthrough of running NVIDIA Nemotron 3.5 Super VL 120B-A12B (Early Access; BF16 and NVFP4 checkpoints) on Amazon [EKS](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html) or SageMaker [HyperPod EKS](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-eks.html), following the same pattern as the neighboring [nemotron/ultra](../ultra) deployment.

To simplify the deployment and testing we follow the principles of the [do-framework](https://bit.ly/do-framework) and provide automation as part of the [aws-do-eks](https://bit.ly/do-eks) project.

**Status: every deployment cell in this folder is UNTESTED until [test/RESULTS.md](test/RESULTS.md) says otherwise.** The manifests have passed rendering and `kubectl apply --dry-run=client` validation; two cells (BF16 `agg/deployment` and BF16 `disagg/deployment`) have each served requests in one smoke launch, recorded in RESULTS.md, and no cell has been measured. The checkpoint facts below come from the Early-Access checkpoint's own `config.json`.

## The model, from its config.json

* `architectures = ["NemotronH_Omni_Reasoning_V3"]`, `model_type = nemotron_h_omni` — a vision-language (Omni) wrapper around a `NemotronHForCausalLM` hybrid-Mamba MoE LLM. The vision tower is RADIO (ViT-H, hidden 1280, 32 layers, patch 16, `force_image_size` 512); `sound_config` is `null` in this checkpoint, so audio input is disabled by the model itself (image and video content types go through vLLM's `nano_nemotron_vl` implementation).
* LLM core: 88 layers (40 mamba / 40 moe / 8 attention), hidden 4096, 512 routed experts with 22 active per token + 1 shared expert, vocab 131072, `max_position_embeddings` 1048576, `mamba_ssm_cache_dtype float32`.
* MTP: `num_nextn_predict_layers = 1`, `mtp_layers_block_type = ["attention","moe"]` — the "mtp_boosted" in the EA directory name. The `SPEC_DECODE` toggle in the `.env` files exposes it (OFF by default, see below).
* BF16 checkpoint ≈ 249 GB (63 safetensors shards): **one 8-GPU H200/B200 node holds it with KV headroom** (~31 GB/GPU weights at TP8). This is why — deliberately, and unlike `../ultra` — there are **no two-node LWS/PP2/wide-EP manifest types** here: the multinode engine shapes exist in the ultra tree to fit a 550B model, a problem this model does not have. The matrix is single node for aggregated, and one node per role for disaggregated.

## Prerequisites

Identical to [nemotron/ultra](../ultra/README.md#prerequisites): the `aws-do-eks` shell (optional), a cluster with at least one 8-GPU H200/B200 node for aggregated (two for disaggregated P/D), the [EBS](https://github.com/aws-samples/aws-do-eks/tree/main/Container-Root/eks/deployment/csi/ebs) and [FSx](https://github.com/aws-samples/aws-do-eks/tree/main/Container-Root/eks/deployment/csi/fsx) CSI drivers with an `fsx-pvc` claim, the [NVIDIA device plugin](https://github.com/aws-samples/aws-do-eks/blob/main/Container-Root/eks/deployment/nvidia-device-plugin/), the [EFA device plugin](https://github.com/aws-samples/aws-do-eks/tree/main/Container-Root/eks/deployment/efa-device-plugin) (disagg/epd only), and the [NVIDIA Dynamo platform](https://github.com/aws-samples/aws-do-eks/tree/main/Container-Root/eks/deployment/nvidia-dynamo). The Leader Worker Set controller is NOT needed (no LWS templates here).

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
| `agg/` | `dgd` | `DynamoGraphDeployment`, one worker (needs the Dynamo operator) | 1 | no |
| `agg/` | `dgd-v1beta1` | the same deployment on `nvidia.com/v1beta1` — the CRD's **storage version** on a Dynamo 1.5.0 platform | 1 | no |
| `disagg/` | `deployment` | 1 prefill + 1 decode, TP8/PP1 each, KV over EFA via NIXL LIBFABRIC | 2 | yes |
| `disagg/` | `epd` | dedicated vision-ENCODE worker + one aggregated PD worker (dynamo v1.5.0's `disagg_multimodal_e_pd.sh` shape) — **read the template header for a verified upstream caveat** | 1 + encode | encode only |
| `disagg/` | `dgd` | `DynamoGraphDeployment` prefill + decode | 2 | yes |
| `disagg/` | `dgd-v1beta1` | the same on `nvidia.com/v1beta1` | 2 | yes |

Multimodal serving facts baked into the templates, taken from dynamo v1.5.0's own launch scripts (`examples/backends/vllm/launch/agg_multimodal.sh`, `disagg_multimodal_p_d.sh`, `disagg_multimodal_e_pd.sh`): every worker runs `--enable-multimodal`; decode/PD workers add `--enable-mm-embeds`; the EPD encode worker runs `--disaggregation-mode encode` and the PD worker `--route-to-encoder --disaggregation-mode pd`; aggregated and EPD graphs set `DYN_REQUEST_PLANE=tcp` (base64 images exceed the NATS 1 MB payload limit — the P/D launch script does not set it, and neither do the P/D templates).

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
./models-list.sh          # names of the hosted models
./models-health.sh        # deployment health + endpoints
./test-completions.sh     # one text request to /v1/completions
./test-chat-completions.sh  # one text request to /v1/chat/completions
./test-chat-image.sh      # ONE IMAGE PROMPT via image_url content
./test-aiperf.sh          # aiperf vision workload: synthetic 512x512 images + text
```

`test-aiperf.sh` differs from ultra's in exactly one respect: it benchmarks the **vision path** (`--image-width-mean/--image-height-mean`, aiperf ≥ 0.9.0). Results and the measurement discipline live in [test/RESULTS.md](test/RESULTS.md) — currently a full PENDING grid with zero numbers.

## Relationship to nemotron/ultra

This folder mirrors ultra's layout, scripts and conventions (`.env` + `envsubst` templates, `run.sh`/`stop.sh`, do-pods for download/test, a `dynamo-vllm-efa` golden-image recipe with a CVE gate). Deliberate differences, each stated where it applies: single-node matrix (no LWS/PP2/EP), stock-NGC default image, the `--hf-overrides` architecture alias, multimodal flags + TCP request plane, the EPD template, parameterized `MAX_MODEL_LEN`/`GPU_MEM_UTIL`, `SPEC_DECODE`, pod-network disagg (no host networking anywhere in this tree), and no `--moe-backend` pin (ultra's encodes a vLLM-0.26 measurement that has not been reproduced on 0.28/this model).
