# Nemotron 3.5 Super VL 120B-A12B — AIPerf results

**No cell has been measured yet.** Every template × precision combination below is
PENDING. One manifest, BF16 `agg/deployment`, has served requests in a single smoke
launch (see "Served-request smoke" below); the other manifests in `../agg` and
`../disagg` have passed rendering and `kubectl apply --dry-run=client` validation only.
A row leaves PENDING only when a run through `test-aiperf.sh` (vision
workload: synthetic 512×512 images, ISL 1024 / OSL 512, `--concurrency 10`,
`--request-count 100`, `--random-seed 42`) produces a `profile_export_aiperf.json`
and a `run-meta.json` whose observed workloads match the row's template — the same
discipline as `../../ultra/test/RESULTS.md`.

The GPU column stays empty until a measurement exists; fill it with what actually
served the run (e.g. H200 / B200), never with the intended target. Note for NVFP4 on
H200 (sm90): there is no native FP4 compute — vLLM serves the NVFP4 checkpoint through
its Marlin weight-only fallback (FP4-compressed weights, BF16 compute), so an H200
NVFP4 row measures a different kernel path than a B200 one.

## Fixed-concurrency grid (c=10) — all PENDING

| precision | template | GPU | GPUs | TTFT p50 (ms) | ITL p50 (ms) | tok/s/user p50 | tok/s total | status |
|---|---|---|---|---|---|---|---|---|
| BF16 | `agg/deployment` | | 8 | | | | | PENDING |
| BF16 | `agg/dgd` | | 8 | | | | | PENDING |
| BF16 | `agg/dgd-v1beta1` | | 8 | | | | | PENDING |
| BF16 | `disagg/deployment` | | 16 | | | | | PENDING |
| BF16 | `disagg/dgd` | | 16 | | | | | PENDING |
| BF16 | `disagg/dgd-v1beta1` | | 16 | | | | | PENDING |
| BF16 | `disagg/epd` | | 8+enc | | | | | PENDING¹ |
| NVFP4 | `agg/deployment` | | 8 | | | | | PENDING |
| NVFP4 | `agg/dgd` | | 8 | | | | | PENDING |
| NVFP4 | `agg/dgd-v1beta1` | | 8 | | | | | PENDING |
| NVFP4 | `disagg/deployment` | | 16 | | | | | PENDING |
| NVFP4 | `disagg/dgd` | | 16 | | | | | PENDING |
| NVFP4 | `disagg/dgd-v1beta1` | | 16 | | | | | PENDING |
| NVFP4 | `disagg/epd` | | 8+enc | | | | | PENDING¹ |

¹ `disagg/epd` carries a verified structural caveat before any run is attempted: at
dynamo v1.5.0 the encode worker's loader
(`components/src/dynamo/vllm/multimodal_utils/model.py`, `load_vision_model`) uses the
lightweight encoder-only path only for Qwen-VL families and full-loads every other VL
checkpoint via `AutoModel.from_pretrained` — the BF16 Super-VL checkpoint (~249 GB)
cannot fit the template's default 1-GPU encode worker. See the header of
`../disagg/epd.yaml-template`.

## Spec-decode cells

The `SPEC_DECODE=1` toggle (MTP, `num_speculative_tokens=1`) is OFF in every row above.
When a cell is measured with it on, record it as a SEPARATE row — never fold a
spec-decode number into a non-spec row.

## Served-request smoke (not a benchmark)

A cell listed here has **served** requests; it has not been **measured**. These rows never
move a fixed-concurrency grid row out of PENDING. The latency column comes from one server
launch, with 8 sequential non-streaming requests: a smoke record, not a performance number.

| precision | template | GPU | GPUs | launches | /v1/models | completion | chat | image prompt (red-square test image) | smoke e2e latency, 8 seq. chat, max_tokens 128 (s, min / median / max) | spec-decode | status |
|---|---|---|---|---|---|---|---|---|---|---|---|
| BF16 | `agg/deployment` | NVIDIA H200 | 8 | 1 | 200, model listed | 200, text | 200, text | 200, answer "Red" | 7.79 / 7.80 / 7.82 | off | SERVED (smoke) ² |

² 20261010T000627Z on cgk (one p5en.48xlarge), image `nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.5.0-efa`
(Dynamo 1.5.0 / vLLM 0.28.0) with the `--hf-overrides` NemotronH_Super_Omni_Reasoning_V3
alias. Worker healthy 9.1 min after apply, 0 restarts. The `agg/deployment` manifest ran with
five deployment-only changes: namespace, a private etcd/NATS in place of the platform
services, a node pin, a read-only `fsx-pvc` mount, and a teardown label. The engine flags and
probes are unchanged. Test image: 512×512 PNG, solid (255,0,0) square, sha256
`62c172d4338a40ec…`. Not established: performance, reproducibility across launches,
MTP, NVFP4, disagg/EPD, dgd manifests, B200, long context, concurrency.
The image was sent as an inline `data:` URL, so the remote https image path that
`test-chat-image.sh` uses was **not** exercised. The chat and image answers ended with
`finish_reason=stop`. The 128-token completion and the 8 timing requests may consist entirely
of reasoning text: no reasoning parser is set, so they show that text was served, not that an
answer was.
