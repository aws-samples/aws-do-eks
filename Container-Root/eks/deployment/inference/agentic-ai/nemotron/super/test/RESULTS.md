# Nemotron 3.5 Super VL 120B-A12B — AIPerf results

**Measured so far: BF16 `agg/deployment` and BF16 `disagg/deployment` on H200 (one launch each, c=10 LLM workload; rows and footnotes below).** Every other template × precision combination below is
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
| BF16 | `agg/dgd` | | 8 | | | | | PENDING |
| BF16 | `agg/dgd-v1beta1` | | 8 | | | | | PENDING |
| BF16 | `disagg/deployment` | NVIDIA H200 | 16 | 509.73 | 86.68 | 11.54 | 114.33 | MEASURED ⁵ |
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

⁴ 2026-10-12, window 20261012T193453Z, one server launch on one p5en.48xlarge, TP8 agg worker, image `nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.5.0-efa` (node-recorded digest `sha256:a1bc3d20ea2b…`), the same `--hf-overrides` alias and engine flags as ². Measured with this folder's `test-aiperf.sh` in its default LLM workload (ISL 1024 / OSL 512, `ignore_eos:true`, `--concurrency 10`, `--request-count 100`, `--random-seed 42`, no image flags) and `AIPERF_WARMUP_REQUESTS=0` (no `--warmup-request-count`), i.e. the `../../ultra/test/RESULTS.md` table methodology: a cold run right after the health gate (run id `cold`: TTFT p50 452.09, ITL p50 87.26, tok/s/user p50 11.46, tok/s total 113.09; `profile_export_aiperf.json` sha256 `cd88f74b7eafa756…`), then a warm run on the same launch (run id `warm`), and **the warm run is the row**; both runs completed 100/100 requests with no errors (aiperf 0.9.0). The weights are the Early-Access checkpoint `/shared/nemotron/super/bf16/nemotron_3_5_super_ga_candidate_mtp_boosted_20261001_vv0.1` (`MODEL_PATH` export, the .env's documented override) on a shared FSx this lane may only mount read-only, so the manifest ran with namespace, a private etcd/NATS in place of the platform services, a node pin, a read-only `fsx-pvc` mount, and a teardown label (the same five deployment-only changes as ²), and the aiperf client pod mounted `fsx-pvc` read-only with its artifact directory on an emptyDir (copied out before the pod was deleted) and was pinned to the worker's node; the `aiperf profile` command itself is byte-identical to this script's (only `--artifact-dir` differs). Row artifacts (sha256): `profile_export_aiperf.json` `da503c3049efcf95…`, `profile_export.jsonl` `8c2a9ad6a8dae258…`, `run-meta.json` `6350fbc3ce05abb6…` (`workload: llm`, `warmup_requests: 0`). n=1 launch: one server start, two client runs; reproducibility across launches, tail columns, throughput at saturation, MTP, NVFP4, dgd/epd manifests, B200 and long context are not established. An earlier launch of the same cell the same day (window 20261012T191525Z, on another node of the same node group) passed the health gate and had completed 40 of the cold run's 100 requests when that node received an owner-side instance reboot (19:28:47Z); the frontend logged `Engine was shut down during generation`, the remaining requests failed with 404/503, and the window tore the stack down. That launch is kept as provenance only and contributes nothing to the row.

⁵ 2026-10-12, window 20261012T210839Z, one server launch on two p5en.48xlarge, TP8 prefill on one and TP8 decode on the other (KV prefill→decode via vLLM `NixlConnector`, LIBFABRIC backend over EFA), image `nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.5.0-efa` (node-recorded digest `sha256:a1bc3d20ea2b…`), the same `--hf-overrides` alias and engine flags as ³. Measured with this folder's `test-aiperf.sh` in its default LLM workload (ISL 1024 / OSL 512, `ignore_eos:true`, `--concurrency 10`, `--request-count 100`, `--random-seed 42`, no image flags) and `AIPERF_WARMUP_REQUESTS=0` (no `--warmup-request-count`), i.e. the `../../ultra/test/RESULTS.md` table methodology: a cold run right after the health gate (run id `cold`: TTFT p50 644.36, ITL p50 86.13, tok/s/user p50 11.61, tok/s total 113.37; `profile_export_aiperf.json` sha256 `184e7e64407cacbb…`), then a warm run on the same launch (run id `warm`), and **the warm run is the row**; both runs completed 100/100 requests with no errors (aiperf 0.9.0). The weights are the Early-Access checkpoint `/shared/nemotron/super/bf16/nemotron_3_5_super_ga_candidate_mtp_boosted_20261001_vv0.1` (`MODEL_PATH` export, the .env's documented override) on a shared FSx this lane may only mount read-only, so the manifest ran with namespace, a private etcd/NATS in place of the platform services, a node pin per worker, read-only `fsx-pvc` volumes and `/shared` mounts, a teardown label, and a header comment (the same six deployment-only changes as ³), and the aiperf client pod mounted `fsx-pvc` read-only with its artifact directory on an emptyDir (copied out before the pod was deleted) and was pinned to the decode worker's node; the `aiperf profile` command itself is byte-identical to this script's (only `--artifact-dir` differs). Row artifacts (sha256): `profile_export_aiperf.json` `dc2ec1333f6fa134…`, `profile_export.jsonl` `1b2c7e71f995d56a…`, `run-meta.json` `dd05f05c7a1f43c7…` (`workload: llm`, `warmup_requests: 0`). n=1 launch: one server start, two client runs; reproducibility across launches, an agg-vs-disagg verdict (the two n=1 rows only sit side by side), that every request took the remote-prefill path (KV transfer was verified in the health-gate window, not per request), tail columns, throughput at saturation, MTP, NVFP4, dgd/epd manifests, B200 and long context are not established.

## Spec-decode cells

The `SPEC_DECODE=1` toggle (MTP, `num_speculative_tokens=1`) is OFF in every row above.
When a cell is measured with it on, record it as a SEPARATE row — never fold a
spec-decode number into a non-spec row.

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
