# Nemotron 3.5 Super VL 120B-A12B — AIPerf results

**No cell has been measured yet.** Every template × precision combination below is
PENDING: the manifests in `../agg` and `../disagg` have passed rendering and
`kubectl apply --dry-run=client` validation only — no pod has served this model from
this tree. A row leaves PENDING only when a run through `test-aiperf.sh` (vision
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
