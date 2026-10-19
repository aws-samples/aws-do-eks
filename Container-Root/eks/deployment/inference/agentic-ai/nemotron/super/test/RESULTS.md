# Nemotron 3.5 Super VL 120B-A12B — AIPerf results

**Measured so far on H200: the c=10 LLM rows of BF16 `agg/deployment`, BF16 `disagg/deployment`, NVFP4 `agg/deployment` and NVFP4 `disagg/deployment` (one launch each; rows and footnotes below), and for the two BF16 cells a concurrency sweep c = 1 → 128 with the latency-vs-throughput charts ("Concurrency sweeps" below, one launch each). Attempted and not measured: the two BF16 spec-decode cells (the engine rejects `--speculative-config` for this architecture; "Spec-decode cells" below). Not run: dgd / dgd-v1beta1, epd, the vision row (footnotes 12-14).** Every other template × precision combination below is
PENDING. Two manifests, BF16 `agg/deployment` and BF16 `disagg/deployment`, have each served
requests in a single smoke launch (see "Served-request smoke" below); the other manifests in
`../agg` and `../disagg` have passed rendering and `kubectl apply --dry-run=client`
only.
A row leaves PENDING only when a run through `test-aiperf.sh` in its default LLM workload
(`AIPERF_WORKLOAD=llm`: the text profile identical to `../../ultra/test/test-aiperf.sh` —
ISL 1024 / OSL 512, `--concurrency 10`, `--request-count 100`, `--random-seed 42`, no image
flags — so a row here compares directly with the c=10 rows in `../../ultra/test/RESULTS.md`)
produces a `profile_export_aiperf.json` and a `run-meta.json` whose observed workloads match
the row's template and whose `workload` field reads `llm` — the same discipline as ultra's.
Vision rows are optional and separately labelled: a run with `AIPERF_WORKLOAD=vl` (the same
profile with synthetic 512×512 images added, `run-meta.json` `workload: vl`, artifacts under
a `vl-` run id) is recorded as its own row with a `(vl)` suffix in the template column, and
never moves an LLM row out of PENDING.

The GPU column stays empty until a measurement exists; fill it with what actually
served the run (e.g. H200 / B200), never with the intended target. Note for NVFP4 on
H200 (sm90): there is no native FP4 compute — vLLM serves the NVFP4 checkpoint through
its Marlin weight-only fallback (FP4-compressed weights, BF16 compute), so an H200
NVFP4 row measures a different kernel path than a B200 one.

## Fixed-concurrency grid (c=10)

| precision | template | GPU | GPUs | TTFT p50 (ms) | ITL p50 (ms) | tok/s/user p50 | tok/s total | status |
|---|---|---|---|---|---|---|---|---|
| BF16 | `agg/deployment` | NVIDIA H200 | 8 | 348.46 | 87.30 | 11.45 | 113.56 | MEASURED ⁴ |
| BF16 | `agg/lws` | | 16 | | | | | PENDING ¹⁵ |
| BF16 | `agg/lws-ep` | | 16 | | | | | PENDING ¹⁵ |
| BF16 | `agg/dgd` | | 8 | | | | | PENDING ¹² |
| BF16 | `agg/dgd-v1beta1` | | 8 | | | | | PENDING ¹² |
| BF16 | `agg/dgd-grove` | | 16 | | | | | PENDING ¹⁵ |
| BF16 | `agg/dgd-grove-ep` | | 16 | | | | | PENDING ¹⁵ |
| BF16 | `disagg/deployment` | NVIDIA H200 | 16 | 509.73 | 86.68 | 11.54 | 114.33 | MEASURED ⁵ |
| BF16 | `disagg/lws-2pp` | | 32 | | | | | PENDING ¹⁵ |
| BF16 | `disagg/lws-pp2` | | 32 | | | | | PENDING ¹⁵ |
| BF16 | `disagg/lws-ep` | | 32 | | | | | PENDING ¹⁵ |
| BF16 | `disagg/dgd` | | 16 | | | | | PENDING ¹² |
| BF16 | `disagg/dgd-v1beta1` | | 16 | | | | | PENDING ¹² |
| BF16 | `disagg/dgd-grove` | | 16 | | | | | PENDING ¹⁵ |
| BF16 | `disagg/dgd-grove-pp2` | | 32 | | | | | PENDING ¹⁵ |
| BF16 | `disagg/dgd-grove-ep` | | 32 | | | | | PENDING ¹⁵ |
| BF16 | `disagg/epd` | | 8+enc | | | | | PENDING¹ |
| NVFP4 | `agg/deployment` | NVIDIA H200 | 8 | 387.85 | 97.93 | 10.21 | 101.51 | MEASURED ¹⁰ |
| NVFP4 | `agg/lws` | | 16 | | | | | PENDING ¹⁵ |
| NVFP4 | `agg/lws-ep` | | 16 | | | | | PENDING ¹⁵ |
| NVFP4 | `agg/dgd` | | 8 | | | | | PENDING ¹² |
| NVFP4 | `agg/dgd-v1beta1` | | 8 | | | | | PENDING ¹² |
| NVFP4 | `agg/dgd-grove` | | 16 | | | | | PENDING ¹⁵ |
| NVFP4 | `agg/dgd-grove-ep` | | 16 | | | | | PENDING ¹⁵ |
| NVFP4 | `disagg/deployment` | NVIDIA H200 | 16 | 576.36 | 96.77 | 10.33 | 102.16 | MEASURED ¹¹ |
| NVFP4 | `disagg/lws-2pp` | | 32 | | | | | PENDING ¹⁵ |
| NVFP4 | `disagg/lws-pp2` | | 32 | | | | | PENDING ¹⁵ |
| NVFP4 | `disagg/lws-ep` | | 32 | | | | | PENDING ¹⁵ |
| NVFP4 | `disagg/dgd` | | 16 | | | | | PENDING ¹² |
| NVFP4 | `disagg/dgd-v1beta1` | | 16 | | | | | PENDING ¹² |
| NVFP4 | `disagg/dgd-grove` | | 16 | | | | | PENDING ¹⁵ |
| NVFP4 | `disagg/dgd-grove-pp2` | | 32 | | | | | PENDING ¹⁵ |
| NVFP4 | `disagg/dgd-grove-ep` | | 32 | | | | | PENDING ¹⁵ |
| NVFP4 | `disagg/epd` | | 8+enc | | | | | PENDING¹ |

¹ `disagg/epd` carries a verified structural caveat before any run is attempted: at
dynamo v1.5.0 the encode worker's loader
(`components/src/dynamo/vllm/multimodal_utils/model.py`, `load_vision_model`) uses the
lightweight encoder-only path only for Qwen-VL families and full-loads every other VL
checkpoint via `AutoModel.from_pretrained` — the BF16 Super-VL checkpoint (~249 GB)
cannot fit the template's default 1-GPU encode worker. See the header of
`../disagg/epd.yaml-template`.

⁴ 2026-10-12, window 20261012T193453Z, one server launch on one p5en.48xlarge, TP8 agg worker, image `nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.5.0-efa` (node-recorded digest `sha256:a1bc3d20ea2b…`), the same `--hf-overrides` alias and engine flags as ². Measured with this folder's `test-aiperf.sh` in its default LLM workload (ISL 1024 / OSL 512, `ignore_eos:true`, `--concurrency 10`, `--request-count 100`, `--random-seed 42`, no image flags) and `AIPERF_WARMUP_REQUESTS=0` (no `--warmup-request-count`), i.e. the `../../ultra/test/RESULTS.md` table methodology: a cold run right after the health gate (run id `cold`: TTFT p50 452.09, ITL p50 87.26, tok/s/user p50 11.46, tok/s total 113.09; `profile_export_aiperf.json` sha256 `cd88f74b7eafa756…`), then a warm run on the same launch (run id `warm`), and **the warm run is the row**; both runs completed 100/100 requests with no errors (aiperf 0.9.0). The weights are the Early-Access checkpoint `/shared/nemotron/super/bf16/nemotron_3_5_super_ga_candidate_mtp_boosted_20261001_vv0.1` (`MODEL_PATH` export, the .env's documented override) on a shared FSx this lane may only mount read-only, so the manifest ran with namespace, a private etcd/NATS in place of the platform services, a node pin, a read-only `fsx-pvc` mount, and a teardown label (the same five deployment-only changes as ²), and the aiperf client pod mounted `fsx-pvc` read-only with its artifact directory on an emptyDir (copied out before the pod was deleted) and was pinned to the worker's node; the `aiperf profile` command itself is byte-identical to this script's (only `--artifact-dir` differs). Row artifacts (sha256): `profile_export_aiperf.json` `da503c3049efcf95…`, `profile_export.jsonl` `8c2a9ad6a8dae258…`, `run-meta.json` `6350fbc3ce05abb6…` (`workload: llm`, `warmup_requests: 0`). n=1 launch: one server start, two client runs; reproducibility across launches, tail columns, throughput at saturation, MTP, NVFP4, dgd/epd manifests, B200 and long context are not established. An earlier launch of the same cell the same day (window 20261012T191525Z, on another node of the same node group) passed the health gate and had completed 40 of the cold run's 100 requests when that node received an owner-side instance reboot (19:28:47Z); the frontend logged `Engine was shut down during generation`, the remaining requests failed with 404/503, and the window tore the stack down. That launch is kept as provenance only and contributes nothing to the row.

⁵ 2026-10-12, window 20261012T210839Z, one server launch on two p5en.48xlarge, TP8 prefill on one and TP8 decode on the other (KV prefill→decode via vLLM `NixlConnector`, LIBFABRIC backend over EFA), image `nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.5.0-efa` (node-recorded digest `sha256:a1bc3d20ea2b…`), the same `--hf-overrides` alias and engine flags as ³. Measured with this folder's `test-aiperf.sh` in its default LLM workload (ISL 1024 / OSL 512, `ignore_eos:true`, `--concurrency 10`, `--request-count 100`, `--random-seed 42`, no image flags) and `AIPERF_WARMUP_REQUESTS=0` (no `--warmup-request-count`), i.e. the `../../ultra/test/RESULTS.md` table methodology: a cold run right after the health gate (run id `cold`: TTFT p50 644.36, ITL p50 86.13, tok/s/user p50 11.61, tok/s total 113.37; `profile_export_aiperf.json` sha256 `184e7e64407cacbb…`), then a warm run on the same launch (run id `warm`), and **the warm run is the row**; both runs completed 100/100 requests with no errors (aiperf 0.9.0). The weights are the Early-Access checkpoint `/shared/nemotron/super/bf16/nemotron_3_5_super_ga_candidate_mtp_boosted_20261001_vv0.1` (`MODEL_PATH` export, the .env's documented override) on a shared FSx this lane may only mount read-only, so the manifest ran with namespace, a private etcd/NATS in place of the platform services, a node pin per worker, read-only `fsx-pvc` volumes and `/shared` mounts, a teardown label, and a header comment (the same six deployment-only changes as ³), and the aiperf client pod mounted `fsx-pvc` read-only with its artifact directory on an emptyDir (copied out before the pod was deleted) and was pinned to the decode worker's node; the `aiperf profile` command itself is byte-identical to this script's (only `--artifact-dir` differs). Row artifacts (sha256): `profile_export_aiperf.json` `dc2ec1333f6fa134…`, `profile_export.jsonl` `1b2c7e71f995d56a…`, `run-meta.json` `dd05f05c7a1f43c7…` (`workload: llm`, `warmup_requests: 0`). n=1 launch: one server start, two client runs; reproducibility across launches, an agg-vs-disagg verdict (the two n=1 rows only sit side by side), that every request took the remote-prefill path (KV transfer was verified in the health-gate window, not per request), tail columns, throughput at saturation, MTP, NVFP4, dgd/epd manifests, B200 and long context are not established.

## Concurrency sweeps: aggregated vs disaggregated (H200, c = 1 → 128)

Both sweeps are the same LLM text workload as the table above (ISL 1024 / OSL 512, `ignore_eos:true`, seed 42, aiperf 0.9.0) run through this folder's own `aiperf-sweep.yaml-template` (`aiperf-sweep-run.sh`) with only concurrency varying — c = 1 / 2 / 4 / 8 / 16 / 32 / 64 / 128, 20 waves per phase (`--request-count` = 20 × c), and a per-phase excluded warm-up of 2 waves + 1 request (`--warmup-request-count` = 2 × c + 1). Because the warm-up is excluded, sweep rows are not directly comparable to the warmup=0 c=10 rows above; compare sweep to sweep (the six shipped phases c = 1/4/8/16/32/64 are the same ladder as `../../ultra/test/RESULTS.md`'s sweeps; c = 2 and c = 128 were added so the curve spans 1 → 128). The two cells ran on the same day on the same image, one server launch each; they differ in GPU count (8 vs 16), so the pair is not an equal-GPU comparison.

![agg sweep](sweeps/sweep-agg.png)
![disagg sweep](sweeps/sweep-disagg.png)
![agg vs disagg overlay](sweeps/sweep-overlay-agg-vs-disagg.png)
![throughput scaling](sweeps/sweep-throughput-scaling.png)

The charts plot, per phase, `time_to_first_token.avg` (left axis) and `inter_token_latency.avg` (right axis) against `output_token_throughput.avg` (x), read from each phase's `profile_export_aiperf.json`; a phase that failed validation is a GAP row below and is not plotted.

### BF16 `agg/deployment` — aggregated TP8, 8 GPUs (one p5en.48xlarge) ⁶

| c | requests | TTFT avg (ms) | TTFT p50 | TTFT p90 | TTFT p99 | ITL avg (ms) | ITL p50 | ITL p90 | ITL p99 | request latency p50 (ms) | request latency p99 (ms) | output tok/s | requests/s |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 20 | 203.06 | 218.54 | 221.01 | 224.32 | 84.31 | 84.32 | 84.49 | 84.60 | 43,300.99 | 43,450.28 | 11.83 | 0.023 |
| 2 | 40 | 327.95 | 345.07 | 417.70 | 419.65 | 84.57 | 84.59 | 84.78 | 84.90 | 43,534.43 | 43,730.92 | 23.51 | 0.046 |
| 4 | 80 | 362.75 | 362.89 | 440.07 | 460.80 | 84.40 | 84.39 | 84.58 | 84.86 | 43,489.51 | 43,646.70 | 47.08 | 0.092 |
| 8 | 160 | 362.84 | 338.68 | 442.41 | 453.58 | 86.08 | 86.07 | 86.64 | 86.76 | 44,405.76 | 44,590.49 | 92.34 | 0.180 |
| 16 | 320 | 391.70 | 375.03 | 453.80 | 473.37 | 86.18 | 86.20 | 86.53 | 86.67 | 44,414.79 | 44,696.07 | 184.36 | 0.360 |
| 32 | 640 | 441.93 | 453.90 | 515.83 | 622.18 | 89.26 | 89.23 | 89.91 | 90.19 | 46,045.16 | 46,704.72 | 355.62 | 0.695 |
| 64 | 1280 | 456.78 | 462.87 | 516.44 | 900.99 | 89.77 | 89.63 | 90.58 | 91.18 | 46,170.36 | 47,075.65 | 706.81 | 1.381 |
| 128 | 2560 | 485.20 | 491.78 | 522.29 | 1,361.48 | 91.48 | 91.47 | 92.27 | 92.61 | 47,139.39 | 48,277.27 | 1,386.12 | 2.707 |

### BF16 `disagg/deployment` — prefill TP8 + decode TP8, 16 GPUs (two p5en.48xlarge) ⁷

| c | requests | TTFT avg (ms) | TTFT p50 | TTFT p90 | TTFT p99 | ITL avg (ms) | ITL p50 | ITL p90 | ITL p99 | request latency p50 (ms) | request latency p99 (ms) | output tok/s | requests/s |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 20 | 308.86 | 325.76 | 327.64 | 331.14 | 84.59 | 84.72 | 85.06 | 85.12 | 43,575.33 | 43,822.51 | 11.76 | 0.023 |
| 2 | 40 | 542.57 | 584.36 | 589.47 | 626.46 | 85.07 | 85.08 | 85.45 | 85.77 | 44,036.89 | 44,412.23 | 23.26 | 0.045 |
| 4 | 80 | 558.55 | 584.68 | 594.81 | 762.24 | 84.65 | 84.62 | 85.13 | 85.46 | 43,816.04 | 44,176.23 | 46.72 | 0.091 |
| 8 | 160 | 583.56 | 587.11 | 720.17 | 837.21 | 85.16 | 85.14 | 85.55 | 85.78 | 44,088.06 | 44,521.49 | 92.77 | 0.181 |
| 16 | 320 | 623.12 | 596.86 | 839.38 | 859.87 | 85.44 | 85.38 | 85.92 | 86.30 | 44,175.12 | 44,873.67 | 184.78 | 0.361 |
| 32 | 640 | 668.91 | 685.60 | 785.09 | 939.09 | 89.17 | 88.89 | 90.08 | 90.17 | 46,131.04 | 46,896.65 | 353.96 | 0.691 |
| 64 | 1280 | 723.52 | 720.91 | 898.61 | 1,118.77 | 89.91 | 89.94 | 90.13 | 90.23 | 46,653.31 | 47,008.65 | 701.22 | 1.370 |
| 128 | 2560 | 814.46 | 767.56 | 1,026.09 | 1,600.50 | 91.28 | 91.29 | 91.79 | 91.86 | 47,430.55 | 48,222.36 | 1,378.30 | 2.692 |

### What the two curves show

* **BF16 `agg/deployment`** (8 validated phases): ITL avg stays within 10% of its c=1 value (84.31 ms) through c=128 (91.48 ms); output throughput stays within 80% of linear scaling through c=128 (1,386.12 tok/s vs 1,513.86 linear); at c=128 the cell served 1,386.12 tok/s with TTFT avg 485.20 ms and ITL avg 91.48 ms/token.
* **BF16 `disagg/deployment`** (8 validated phases): ITL avg stays within 10% of its c=1 value (84.59 ms) through c=128 (91.28 ms); output throughput stays within 80% of linear scaling through c=128 (1,378.30 tok/s vs 1,505.22 linear); at c=128 the cell served 1,378.30 tok/s with TTFT avg 814.46 ms and ITL avg 91.28 ms/token.

These are readings of the two n=1 curves with fixed thresholds (10% ITL, 80% of linear), not a model of the engine; the cells differ in GPU count (8 vs 16), so neither reading is an agg-vs-disagg verdict.

⁶ 2026-10-13, window 20261013T043719Z, one server launch on one p5en.48xlarge (TP8 agg worker, one node), image `nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.5.0-efa` (node-recorded digest `sha256:a1bc3d20ea2b…`), the same Early-Access BF16 checkpoint, engine flags and deployment-only changes as the c=10 row above (namespace, private etcd/NATS, node pin, read-only `fsx-pvc` on the serving pods, teardown label). Sweep pod: this folder's `aiperf-sweep.yaml-template` rendered by `source .env; envsubst` (NAMESPACE=antonai, DEPLOYMENT_TYPE=agg, MANIFEST_TYPE=deployment, MODEL_VARIANT=BF16, the EA `MODEL_PATH`), run with four recorded deviations: DS1 the ladder adds c=2 (n=40, w=5) and c=128 (n=2560, w=257) to the shipped six phases and the in-pod `run-metadata.json` lists the same eight; DS2 a `nodeSelector` pinning the sweep pod to the serving node; DS3 the template's own publish to `${MODEL_PATH}/aiperf/agg/deployment/sweep-20261013T044819Z` on the FSx kept as shipped (`fsx-pvc` read-write only on this pod; published: /shared/nemotron/super/bf16/nemotron_3_5_super_ga_candidate_mtp_boosted_20261001_vv0.1/aiperf/agg/deployment/sweep-20261013T044819Z); DS4 the harness waited for the template's `=== BENCH DONE` line, then copied `/tmp/run-bundle` and the pod log out before deleting the pod. aiperf 0.9.0 in `python:3.12-slim`; 8 of 8 phases validated (request_count = 20c, no errors, warm-up 2c+1 excluded, ISL 1024/OSL 512/seed 42, chat/streaming/ignore_eos, n jsonl records). Per-phase `profile_export_aiperf.json` sha256: c1 `a55431e35360026e…`; c2 `901cb3b0ad12df90…`; c4 `35a4c198592ceced…`; c8 `d6eda1e45c2b7894…`; c16 `7ce285f4b12d67fa…`; c32 `0df73a8def32988d…`; c64 `a7167a3b3b43232f…`; c128 `8a12954f0b49024f…`. n=1 launch per cell: one server start, one sweep pod; reproducibility across launches, tails at low concurrency (c=1 is 20 requests), throughput beyond c=128, an agg-vs-disagg verdict beyond the two curves (different GPU counts), B200, NVFP4, MTP, dgd/epd manifests and long context are not established. One harvest note: the window copied the bundle out of the pod with `kubectl cp`, which ended `error: unexpected EOF` after the 21 MB c=128 per-request jsonl, so the harvested copy lacked `c128/profile_export_aiperf.json` and the window's own validator recorded c=128 as GAP (the window verdict stays FAIL at e-sweep in the run record). The sweep pod had already published the complete bundle to `/shared/nemotron/super/bf16/nemotron_3_5_super_ga_candidate_mtp_boosted_20261001_vv0.1/aiperf/agg/deployment/sweep-20261013T044819Z` (DS3, the template's own step) after aiperf logged `Phase profiling complete | completed=2,560, cancelled=0, errors=0` for c=128; the c=128 export was read back from that FSx copy with a CPU-only read-only pod, every one of the 68 other harvested files hashed identical to the FSx copy (the only difference is the cp-truncated, unused `c128/inputs.json`), and the merged bundle re-validated 8 of 8 phases (`RECOVERY.md`, `validation-recovered.json`). The c=128 row therefore comes from the same launch and the same aiperf run as the other seven; its export file came from the FSx publish instead of the pod copy.
⁷ 2026-10-13, window 20261013T043724Z, one server launch on two p5en.48xlarge (TP8 prefill on one node, TP8 decode on the other), image `nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.5.0-efa` (node-recorded digest `sha256:a1bc3d20ea2b…`), the same Early-Access BF16 checkpoint, engine flags and deployment-only changes as the c=10 row above (namespace, private etcd/NATS, node pin, read-only `fsx-pvc` on the serving pods, teardown label). Sweep pod: this folder's `aiperf-sweep.yaml-template` rendered by `source .env; envsubst` (NAMESPACE=antonai, DEPLOYMENT_TYPE=disagg, MANIFEST_TYPE=deployment, MODEL_VARIANT=BF16, the EA `MODEL_PATH`), run with four recorded deviations: DS1 the ladder adds c=2 (n=40, w=5) and c=128 (n=2560, w=257) to the shipped six phases and the in-pod `run-metadata.json` lists the same eight; DS2 a `nodeSelector` pinning the sweep pod to the decode node; DS3 the template's own publish to `${MODEL_PATH}/aiperf/disagg/deployment/sweep-20261013T045417Z` on the FSx kept as shipped (`fsx-pvc` read-write only on this pod; published: /shared/nemotron/super/bf16/nemotron_3_5_super_ga_candidate_mtp_boosted_20261001_vv0.1/aiperf/disagg/deployment/sweep-20261013T045417Z); DS4 the harness waited for the template's `=== BENCH DONE` line, then copied `/tmp/run-bundle` and the pod log out before deleting the pod. aiperf 0.9.0 in `python:3.12-slim`; 8 of 8 phases validated (request_count = 20c, no errors, warm-up 2c+1 excluded, ISL 1024/OSL 512/seed 42, chat/streaming/ignore_eos, n jsonl records). Per-phase `profile_export_aiperf.json` sha256: c1 `f07d1a26a06fdfd0…`; c2 `198c725137ed2069…`; c4 `f5724f5054fa5e36…`; c8 `b773a0945197d256…`; c16 `336cbc86a6ff86d6…`; c32 `470c859b6d4fcde4…`; c64 `1c300a5703e47c87…`; c128 `2b0fe069443de02e…`. n=1 launch per cell: one server start, one sweep pod; reproducibility across launches, tails at low concurrency (c=1 is 20 requests), throughput beyond c=128, an agg-vs-disagg verdict beyond the two curves (different GPU counts), B200, NVFP4, MTP, dgd/epd manifests and long context are not established. One harvest note: the window copied the bundle out of the pod with `kubectl cp`, which ended `error: unexpected EOF` after the 21 MB c=128 per-request jsonl, so the harvested copy lacked `c128/profile_export_aiperf.json` and the window's own validator recorded c=128 as GAP (the window verdict stays FAIL at e-sweep in the run record). The sweep pod had already published the complete bundle to `/shared/nemotron/super/bf16/nemotron_3_5_super_ga_candidate_mtp_boosted_20261001_vv0.1/aiperf/disagg/deployment/sweep-20261013T045417Z` (DS3, the template's own step) after aiperf logged `Phase profiling complete | completed=2,560, cancelled=0, errors=0` for c=128; the c=128 export was read back from that FSx copy with a CPU-only read-only pod, every one of the 68 other harvested files hashed identical to the FSx copy (the only difference is the cp-truncated, unused `c128/inputs.json`), and the merged bundle re-validated 8 of 8 phases (`RECOVERY.md`, `validation-recovered.json`). The c=128 row therefore comes from the same launch and the same aiperf run as the other seven; its export file came from the FSx publish instead of the pod copy.

## Spec-decode cells

The `SPEC_DECODE=1` toggle (MTP, `num_speculative_tokens=1`) is OFF in every row above.
When a cell is measured with it on, record it as a SEPARATE row — never fold a
spec-decode number into a non-spec row.

| precision | template | GPU | GPUs | TTFT p50 (ms) | ITL p50 (ms) | tok/s/user p50 | tok/s total | status |
|---|---|---|---|---|---|---|---|---|
| BF16 | `agg/deployment` | | 8 | | | | | NOT MEASURED ⁸ |
| BF16 | `disagg/deployment` | | 16 | | | | | NOT MEASURED ⁹ |

⁸ 2026-10-13, window 20261013T072830Z: the BF16 `agg/deployment` cell with `SPEC_DECODE=1` (the scaffold's own toggle: `--speculative-config '{"method":"mtp","num_speculative_tokens":1}'` on the worker) was attempted on one p5en.48xlarge, TP8 worker and did **not** reach the measurement: window verdict FAIL at `c-worker-healthy` (worker CRASHED: nemotron35-super-vl-120b-agg-worker-6644df759f-xchqg: restarts=1 terminated=[{'exitCode': 1, 'finishedAt': '2026-10-13T07:30:02Z', 'reason': 'Error', 'startedAt': '2026-10-13T07:29:24Z'}] waiting=[]). The worker's crashed container logged: `ValidationError: 1 validation error for SpeculativeConfig   Value error, Model architectures ['NemotronH_Omni_Reasoning_V3'] are not supported for now. Supported architectures: dict_keys(['AfmoeForCausalLM', 'ApertusForCausalLM', 'ArceeForCausalLM', 'ArcticForCausalLM', 'AXK1ForCausalLM', 'BailingMoeForCausalLM', 'BailingMoeV2ForCausalLM', 'BailingMoeV2_5ForCausalLM', 'BailingMoeV3ForCausalLM', 'B`. The scaffold's `.env` already marks the MTP path UNVERIFIED on this architecture; at vLLM 0.28.0 (the engine in `vllm-runtime:1.5.0-efa`) `SpeculativeConfig` rejects the checkpoint's architecture, so no spec-decode number exists for this cell and the engine was torn down (0 GPU idle). The row stays PENDING.

⁹ 2026-10-13, window 20261013T073103Z: the BF16 `disagg/deployment` cell with `SPEC_DECODE=1` (the scaffold's own toggle: `--speculative-config '{"method":"mtp","num_speculative_tokens":1}'` on prefill and decode) was attempted on two p5en.48xlarge, TP8 prefill on one node and TP8 decode on the other (KV prefill→decode via vLLM `NixlConnector`, LIBFABRIC backend over EFA) and did **not** reach the measurement: window verdict FAIL at `c-worker-healthy` (prefill CRASHED: nemotron35-super-vl-120b-disagg-prefill-7547bb8589-vzx6w: restarts=1 terminated=[{'exitCode': 1, 'finishedAt': '2026-10-13T07:33:03Z', 'reason': 'Error', 'startedAt': '2026-10-13T07:32:26Z'}] waiting=[]). The worker's crashed container logged: `ValidationError: 1 validation error for SpeculativeConfig   Value error, Model architectures ['NemotronH_Omni_Reasoning_V3'] are not supported for now. Supported architectures: dict_keys(['AfmoeForCausalLM', 'ApertusForCausalLM', 'ArceeForCausalLM', 'ArcticForCausalLM', 'AXK1ForCausalLM', 'BailingMoeForCausalLM', 'BailingMoeV2ForCausalLM', 'BailingMoeV2_5ForCausalLM', 'BailingMoeV3ForCausalLM', 'B`. The scaffold's `.env` already marks the MTP path UNVERIFIED on this architecture; at vLLM 0.28.0 (the engine in `vllm-runtime:1.5.0-efa`) `SpeculativeConfig` rejects the checkpoint's architecture, so no spec-decode number exists for this cell and the engine was torn down (0 GPU idle). The row stays PENDING.

¹⁰ 2026-10-13, window 20261013T073500Z, one server launch on one p5en.48xlarge, TP8 worker, image `nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.5.0-efa` (node-recorded digest `sha256:a1bc3d20ea2b…`), with `MODEL_VARIANT=NVFP4` and `MODEL_PATH=/shared/nemotron/super/nvfp4/nemotron_3_5_super_ga_candidate_mtp_boosted_nvfp4_20261001_vv0.1` (the Early-Access NVFP4 checkpoint; served name `nvidia/NVIDIA-Nemotron-3.5-Super-VL-120B-A12B-NVFP4`; on H200 vLLM serves it through the Marlin weight-only FP4 fallback, BF16 compute, and `WARMUP_ENABLED=auto` turns the frontend warmer on); every other engine flag and deployment-only change as the BF16 row of the same template (namespace, private etcd/NATS, node pin, read-only `fsx-pvc`, teardown label). Measured with this folder's `test-aiperf.sh` default LLM workload (ISL 1024 / OSL 512, `ignore_eos:true`, `--concurrency 10`, `--request-count 100`, `--random-seed 42`) and `AIPERF_WARMUP_REQUESTS=0`: cold run right after the health gate (run id `cold`: TTFT p50 411.81, ITL p50 96.46, tok/s/user p50 10.37, tok/s total 103.24), then a warm run on the same launch (run id `warm`), **the warm run is the row**; both runs 100/100 requests, no errors (aiperf 0.9.0). Row artifacts (sha256): `profile_export_aiperf.json` `125915aaa5c18c35…`, `profile_export.jsonl` `717bb679b87e8547…`, `run-meta.json` `8c0a06c243a310e0…`. n=1 launch; reproducibility across launches, tails, saturation and the other precisions/manifests are not established.

¹¹ 2026-10-13, window 20261013T080334Z, one server launch on two p5en.48xlarge, TP8 prefill on one node and TP8 decode on the other (KV prefill→decode via vLLM `NixlConnector`, LIBFABRIC backend over EFA), image `nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.5.0-efa` (node-recorded digest `sha256:a1bc3d20ea2b…`), with `MODEL_VARIANT=NVFP4` and `MODEL_PATH=/shared/nemotron/super/nvfp4/nemotron_3_5_super_ga_candidate_mtp_boosted_nvfp4_20261001_vv0.1` (the Early-Access NVFP4 checkpoint; served name `nvidia/NVIDIA-Nemotron-3.5-Super-VL-120B-A12B-NVFP4`; on H200 vLLM serves it through the Marlin weight-only FP4 fallback, BF16 compute, and `WARMUP_ENABLED=auto` turns the frontend warmer on); every other engine flag and deployment-only change as the BF16 row of the same template (namespace, private etcd/NATS, node pin, read-only `fsx-pvc`, teardown label). Measured with this folder's `test-aiperf.sh` default LLM workload (ISL 1024 / OSL 512, `ignore_eos:true`, `--concurrency 10`, `--request-count 100`, `--random-seed 42`) and `AIPERF_WARMUP_REQUESTS=0`: cold run right after the health gate (run id `cold`: TTFT p50 587.69, ITL p50 97.89, tok/s/user p50 10.22, tok/s total 101.14), then a warm run on the same launch (run id `warm`), **the warm run is the row**; both runs 100/100 requests, no errors (aiperf 0.9.0). Row artifacts (sha256): `profile_export_aiperf.json` `576862e49931d528…`, `profile_export.jsonl` `cff1b37d5478cb3a…`, `run-meta.json` `f47feb6406ef8ae1…`. n=1 launch; reproducibility across launches, tails, saturation and the other precisions/manifests are not established.

¹² 2026-10-13: the `agg/dgd`, `agg/dgd-v1beta1`, `disagg/dgd` and `disagg/dgd-v1beta1` cells were **not run** in this campaign. Read-only facts gathered first: the cluster's Dynamo operator (`dynamo-system/dynamo-platform-dynamo-operator-controller-manager`, image `kubernetes-operator:1.4.0`) is cluster-scoped (manager ClusterRoleBinding, no namespace restriction in its `OperatorConfiguration`) and the `dynamographdeployments.nvidia.com` CRD serves `v1alpha1` (storage) and `v1beta1`, so a DGD in this namespace would be reconciled without any platform change. The cells were still not attempted because (1) these templates target a Dynamo **1.5.0** platform (`dgd-v1beta1` is storage-native only there) while the installed operator is 1.4.0, an untested version skew for the 1.5.0 `vllm-runtime` image; (2) operator-managed pods use the platform's shared etcd/NATS, which every measured cell above avoided by design with a private control plane; and (3) the campaign's time budget went to the sweeps and the spec-decode/NVFP4 cells. No DGD object was created. The rows stay PENDING.

¹³ 2026-10-13: `disagg/epd` (BF16 and NVFP4) stays **not run**, per the verified structural caveat in footnote 1 (the encode worker full-loads the VL checkpoint on one GPU at dynamo v1.5.0); nothing was attempted. The rows stay PENDING.

¹⁴ 2026-10-13: the optional vision row (`AIPERF_WORKLOAD=vl`, synthetic 512×512 images on the c=10 profile) was **not run** for any cell in this campaign; the LLM rows and sweeps above exercise the text path only. No `(vl)` row is added.

¹⁵ 2026-10-17: the ten multinode and Grove templates (`agg/lws`, `agg/lws-ep`, `agg/dgd-grove`, `agg/dgd-grove-ep`, `disagg/lws-2pp`, `disagg/lws-pp2`, `disagg/lws-ep`, `disagg/dgd-grove`, `disagg/dgd-grove-pp2`, `disagg/dgd-grove-ep`) were added for `MANIFEST_TYPE` parity with `../../ultra` and were **not run** in this change: no cluster was available to it, so the templates are render-validated only (`run.sh` driven with a stubbed `kubectl` for every type × BF16/NVFP4, YAML parse, landed-value asserts, `kubectl apply --dry-run=client`; server-side validation was not possible). GPU counts are the `.env` defaults (`EP_DP_SIZE=2`, `NODE_COUNT_PER_WORKER=2`). Each template is ultra's with only the Super delta applied; the PP>1 disagg cells (`lws-2pp`, `lws-pp2`, `dgd-grove-pp2`) additionally carry the stock-vLLM-0.28 caveat from their template headers (on ultra those shapes required the `:1.4.0-patched` image). The rows stay PENDING.

## Served-request smoke (not a benchmark)

A cell listed here has **served** requests; it has not been **measured**. These rows never
move a fixed-concurrency grid row out of PENDING. Each row's latency column comes from one
server launch of that row's manifest, with 8 sequential non-streaming requests: a smoke
record, not a performance number. The rows do not compare one manifest with another.

| precision | template | GPU | GPUs | launches | /v1/models | completion | chat | image prompt (red-square test image) | smoke e2e latency, 8 seq. chat, max_tokens 128 (s, min / median / max) | spec-decode | status |
|---|---|---|---|---|---|---|---|---|---|---|---|
| BF16 | `agg/deployment` | NVIDIA H200 | 8 | 1 | 200, model listed | 200, text | 200, text | 200, answer "Red" | 7.79 / 7.80 / 7.82 | off | SERVED (smoke) ² |
| BF16 | `disagg/deployment` | NVIDIA H200 | 16 | 1 | 200, model listed | 200, text | 200, text | 200, answer "Red" | 7.88 / 7.94 / 8.47 | off | SERVED (smoke) ³ |

² 20261010T000627Z on one p5en.48xlarge, image `nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.5.0-efa`
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

³ 20261010T093419Z on two p5en.48xlarge (8× H200 each): one TP8 prefill worker and one TP8 decode
worker, each pinned to its own node, with the same image (same digest) and `--hf-overrides` alias
as ². The KV-transfer config is vLLM's `NixlConnector` with the LIBFABRIC backend. Both workers
healthy 5.6 min after apply, 0 restarts; the same two worker pods, still at 0 restarts, served the
whole client run. Across the client run the decode node's EFA `rdma_read_bytes` counter (summed
over its 16 EFA devices, read before and after the run) rose by 1,140,097,024 B, the prefill
node's `rdma_read_resp_bytes` rose by the same amount, and neither counter moved in an idle
interval read just before the run. Inside the same window the decode worker's log reports 80
successful NIXL transfers (the sum of its `KV Transfer metrics` lines, counted from the log, not
read from vLLM's transfer counter), and neither worker's log has a NIXL failure line. These counts
are cumulative over the run: they show that the decode worker pulled KV from the prefill node over
EFA during the run, not that every request took that path. The `disagg/deployment` manifest ran
with six deployment-only changes: namespace, a private etcd/NATS in place of the platform
services, a node pin per worker, read-only `fsx-pvc` volumes and `/shared` mounts, a teardown
label, and a header comment. The engine flags, the KV-transfer settings and the probes are
unchanged. Test image as ² (sha256 `62c172d4338a40ec…`), sent as an inline `data:` URL. The chat,
image and timing requests ended with `finish_reason=stop`; the completion stopped at its 128-token
limit. No reasoning parser is set, so the completion and the 8 timing replies show that text was
served, not that an answer was. This is an n=1 launch smoke, not a performance cell. Not
established, copied verbatim from the run's result record (there, `d2` is the completion request
and `e` the 8 timing requests, both with `max_tokens` 128):

- any performance number or comparison: TTFT/ITL/throughput/latency floors, KV-transfer bandwidth or latency (NIXL 'Avg xfer time'/'Avg MB per transfer' are recorded, not measured cells), or any agg-vs-disagg statement; the c=10 aiperf grid rows in test/RESULTS.md stay PENDING
- reproducibility across launches (n=1 launch; client repetitions inside one launch are not independent starts)
- that EVERY request took the remote-prefill path (the counters and the NIXL counts are cumulative over the client run; per-request attribution is not made)
- that GDRCopy (/dev/gdrdrv) was used by the transfer path (the device is mounted; its use is not measured), or multi-rail EFA (the scaffold sets NIXL_LIBFABRIC_MAX_RAILS=1)
- MTP / SPEC_DECODE=1
- the NVFP4 checkpoint
- disagg/epd or the dgd / dgd-v1beta1 manifest types
- B200 / p6 or any other instance type
- long context or concurrency (short prompts, sequential requests only; MAX_MODEL_LEN 32768 not exercised)
- video or audio input; output quality beyond one colour word; that the 128-token d2/e texts contain an answer rather than reasoning
- the scaffold's default shared-platform etcd/NATS path (a private control plane was used), a read-write /shared mount, or the remote https image path (test-chat-image.sh fetches an https URL; this cell sent an inline data: URL)
- the cold-start warmup path (WARMUP_ENABLED=auto skips BF16)
