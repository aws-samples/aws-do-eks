# Nemotron 3 Ultra 550B — measured AIPerf results (B200, re-measured 2026-08-24..26)

Benchmark results for every deployment template in this folder's `agg/` and `disagg/` directories, at both published precisions of the model, measured with the harness in this directory (`test-aiperf.sh` for the fixed-concurrency rows, `aiperf-sweep-run.sh` for the sweeps). Numbers marked *raw aiperf export* are parsed from the `profile_export_aiperf.json` that aiperf 0.9.0 wrote for that run — none are transcribed by hand.

Common to every fixed-concurrency row: Input Sequence Length (ISL) 1024 (stddev 0) / Output Sequence Length (OSL) 512 with `ignore_eos:true`, 100 requests, `--concurrency 10`, `--random-seed 42`, `--warmup-request-count 0`, on a SageMaker HyperPod EKS cluster with 4× p6-b200 nodes (8× B200 each). Each row was run twice on the same stack: cold right after the pods went Ready, then again after a warm interval, and the **warm run is the published row**; the cold companion is kept as provenance. Runs carry a `run-meta.json` that records what actually served them (the observed workload kinds and DYN_NAMESPACE).

This table is a full re-measure of the grid (2026-08-24..26): 21 of the 23 template × precision cells were rebuilt end-to-end — deploy, cold run, warm run, teardown — serially on the **same image build** (`public.ecr.aws/hpc-cloud/dynamo-vllm-efa:1.4.0-patched`, node-recorded image digest `sha256:8332b609a2ed…` constant across the whole campaign) with the templates at their current revision, so every row is comparable to every other row with no image or template drift between cells. The two `disagg/lws-2pp` rows († below) could not be re-measured and retain their prior campaign's numbers — see Coverage.

## Fixed-concurrency comparison (c=10)

| precision | template | GPUs | TTFT p50 (ms) | TTST p50 (ms) | ITL p50 (ms) | tok/s/user p50 | tok/s total | tok/s per GPU | basis |
|---|---|---|---|---|---|---|---|---|---|
| BF16 | `agg/deployment` | 8 | 489.64 | 45.29 | 92.09 | 10.86 | 107.67 | 13.46 | raw aiperf export |
| BF16 | `agg/dgd` | 8 | 467.43 | 122.66 | 91.44 | 10.94 | 108.36 | 13.54 | raw aiperf export |
| BF16 | `agg/dgd-grove` | 16 | 352.81 | 163.54 | 51.97 | 19.24 | 189.26 | 11.83 | raw aiperf export |
| BF16 | `agg/dgd-grove-ep` | 16 | 389.47 | 155.32 | 108.07 | 9.25 | 91.85 | 5.74 | raw aiperf export |
| BF16 | `agg/lws` | 16 | 464.34 | 13.25 | 49.59 | 20.16 | 198.80 | 12.43 | raw aiperf export |
| BF16 | `agg/lws-ep` | 16 | 381.88 | 139.96 | 107.23 | 9.33 | 92.66 | 5.79 | raw aiperf export |
| BF16 | `disagg/deployment` | 16 | 548.68 | 91.58 | 91.40 | 10.94 | 107.48 | 6.72 | raw aiperf export |
| BF16 | `disagg/dgd` | 16 | 549.50 | 91.88 | 91.59 | 10.92 | 107.87 | 6.74 | raw aiperf export |
| BF16 | `disagg/dgd-grove` | 16 | 549.64 | 92.14 | 91.59 | 10.92 | 107.79 | 6.74 | raw aiperf export |
| BF16 | `disagg/dgd-grove-ep` | 32 | 666.61 | 109.64 | 109.95 | 9.10 | 90.01 | 2.81 | raw aiperf export |
| BF16 | `disagg/dgd-grove-pp2` | 32 | 364.24 | 52.00 | 52.18 | 19.16 | 188.73 | 5.90 | raw aiperf export |
| BF16 | `disagg/lws-2pp`† | 32 | 546.13 | 88.22 | 88.32 | 11.32 | 110.94 | 3.47 | raw aiperf export |
| BF16 | `disagg/lws-ep` | 32 | 745.77 | 108.01 | 107.53 | 9.30 | 91.44 | 2.86 | raw aiperf export |
| BF16 | `disagg/lws-pp2` | 32 | 347.31 | 50.65 | 49.70 | 20.12 | 198.30 | 6.20 | raw aiperf export |
| NVFP4 | `agg/deployment` | 8 | 644.29 | 186.07 | 186.21 | 5.37 | 51.28 | 6.41 | raw aiperf export |
| NVFP4 | `agg/dgd` | 8 | 673.23 | 225.01 | 186.09 | 5.38 | 52.78 | 6.60 | raw aiperf export |
| NVFP4 | `agg/lws` | 16 | 535.58 | 225.11 | 101.03 | 9.90 | 96.46 | 6.03 | raw aiperf export |
| NVFP4 | `agg/lws-ep` | 16 | 740.31 | 233.75 | 263.71 | 3.79 | 37.96 | 2.37 | raw aiperf export |
| NVFP4 | `disagg/deployment` | 16 | 1,068.46 | 179.76 | 186.74 | 5.36 | 50.16 | 3.13 | raw aiperf export |
| NVFP4 | `disagg/dgd` | 16 | 1,048.05 | 173.77 | 187.42 | 5.34 | 51.28 | 3.21 | raw aiperf export |
| NVFP4 | `disagg/lws-2pp`† | 32 | 742.68 | 123.78 | 132.85 | 7.53 | 47.36\* | 1.48\* | raw aiperf export |
| NVFP4 | `disagg/lws-ep` | 32 | 1,604.70 | 238.89 | 286.17 | 3.49 | 35.27 | 1.10 | raw aiperf export |
| NVFP4 | `disagg/lws-pp2` | 32 | 669.71 | 94.41 | 103.35 | 9.68 | 94.32 | 2.95 | raw aiperf export |

† `disagg/lws-2pp` did not deploy on the 2026-08-24..26 image build (see Coverage); these two rows are the prior campaign's measure (2026-08-15..18) on the image build current at that time and are **not** directly comparable to the re-measured rows.

\* total-throughput columns contaminated by stalls in that run's wall clock (applies only to the retained prior-campaign NVFP4 `disagg/lws-2pp` row).

### How to read this table

1. **Compare on ITL p50 and TTFT p50.** At fixed concurrency and pinned output length there is essentially one independent latency number per row: tok/s/user ≈ 1000/ITL and total ≈ that × concurrency, so quoting all columns is quoting ITL several times.
2. **No fixed-concurrency row is a throughput result.** c=10 is latency-bound, nowhere near saturation; the sweeps below are the throughput data.
3. **Tails need repeats.** Each published row is one warm run of 100 requests; p90/p99/max on such a run can be a single request. Every re-measured row has a same-stack cold companion, and their tail behaviour is characterized in the caveats.
4. **Cross-precision comparisons must hold the template fixed.** On this image build the same-shape non-EP pairs are remarkably consistent: NVFP4 runs 2.02–2.08× the BF16 ITL p50 across all six pairs (`agg/deployment` 92.09 vs 186.21, `agg/lws` 49.59 vs 101.03, …); the two expert-parallel pairs are wider (2.46–2.66×). BF16 is consistently faster per token on B200 for this model.
5. **PP2 is the latency lever.** The TP8/PP2 shapes (`agg/lws`, `agg/dgd-grove`, `disagg/lws-pp2`, `disagg/dgd-grove-pp2`) run ITL 50–52 ms vs 91–92 ms for every TP8/PP1 shape at BF16 (same split at NVFP4: ~101 vs ~186 ms) — and the PP>1 correctness gate below is what makes those rows quotable.
6. **The Grove-rendered DGD templates cost nothing.** Each `dgd-grove*` variant lands within ~5% ITL p50 of the hand-rolled template with the same engine shape (`agg/dgd-grove` 51.97 vs `agg/lws` 49.59, `disagg/dgd-grove-pp2` 52.18 vs `disagg/lws-pp2` 49.70, …), so the operator/Grove rendering path is not a latency decision at c=10.

### Caveats measured on the cold+warm pairs

* **BF16 TTFT tails are a cold-engine effect and a warm run removes them** (13 of 13 pairs): cold-run TTFT p95 sits at 1.1–3.0 s (the opening concurrency wave paying JIT), while the warm run's p95 drops to 451–1,473 ms. Meanwhile ITL p50 moved <1% cold-to-warm on every pair — the published latency numbers are steady-state, not warmup artifacts. The one warm-side outlier is `agg/dgd-grove` (warm p95 1,472.52 vs p50 352.81 — a top-decile TTFT step on that single run, not an ITL effect).
* **NVFP4 TTFT tails are smaller than previously measured but are NOT cold-engine:** the multi-minute mid-run holds seen in the 2026-08-17 campaign did not recur (worst warm TTFT p95 this campaign: 4.79 s, `disagg/deployment`), but on four of eight re-measured NVFP4 rows the warm p95 is equal to or worse than the cold one — second-scale TTFT tails recur mid-run at this precision, so columns above p50 on those rows describe that tail, not a warmup transient. All NVFP4 runs completed 100/100 requests with no errors; total-throughput columns are honest wall-clock numbers this campaign.

## Concurrency sweeps: aggregated vs disaggregated at equal GPU count

Both sweeps are the same experiment as the table above (ISL 1024 / OSL 512, ignore_eos, seed 42, aiperf 0.9.0) with only concurrency varying — c = 1/4/8/16/32/64, 20 waves per phase, and a per-phase excluded warm-up (2 waves + 1). Because the warm-up is excluded, sweep rows are not directly comparable to the warmup=0 table rows; compare sweep to sweep. The pair holds GPU count fixed at 16: `agg/lws` (aggregated TP8/PP2 spanning 2 nodes) vs `disagg/deployment` (prefill TP8 + decode TP8, one node each). The sweeps were measured on 2026-08-17 and are not part of the 2026-08-24..26 re-measure; their within-pair comparison holds one image constant.

### BF16 agg/lws — aggregated TP8/PP2, 16 GPUs

| c | n | TTFT p50 (ms) | TTFT p99 (ms) | ITL p50 (ms) | tok/s/user p50 | tok/s total | duration (s) |
|---|---|---|---|---|---|---|---|
| 1 | 20 | 122.14 | 126.95 | 48.78 | 20.50 | 20.45 | 500.8 |
| 4 | 80 | 299.69 | 328.25 | 49.04 | 20.39 | 80.82 | 506.8 |
| 8 | 160 | 453.05 | 487.58 | 49.25 | 20.30 | 159.84 | 512.5 |
| 16 | 320 | 549.21 | 860.80 | 49.61 | 20.16 | 315.26 | 519.6 |
| 32 | 640 | 716.89 | 1,253.61 | 50.91 | 19.64 | 611.94 | 535.2 |
| 64 | 1280 | 887.31 | 2,593.74 | 56.48 | 17.70 | 1,099.26 | 595.2 |

### BF16 disagg/deployment — disagg prefill TP8 + decode TP8, 16 GPUs

| c | n | TTFT p50 (ms) | TTFT p99 (ms) | ITL p50 (ms) | tok/s/user p50 | tok/s total | duration (s) |
|---|---|---|---|---|---|---|---|
| 1 | 20 | 223.90 | 238.52 | 89.07 | 11.23 | 11.19 | 915.1 |
| 4 | 80 | 544.22 | 703.94 | 89.35 | 11.19 | 44.28 | 924.9 |
| 8 | 160 | 554.40 | 880.40 | 89.33 | 11.19 | 88.59 | 924.7 |
| 16 | 320 | 560.51 | 1,232.54 | 89.86 | 11.13 | 175.91 | 931.3 |
| 32 | 640 | 567.29 | 1,860.61 | 90.23 | 11.08 | 349.19 | 938.1 |
| 64 | 1280 | 574.84 | 2,979.70 | 93.51 | 10.69 | 672.18 | 974.5 |

### What the sweep pair says

* **No ITL or throughput crossover anywhere in c=1..64.** The aggregated PP2 shape is faster per token at every concurrency (1.83x at c=1, narrowing to 1.66x at c=64) and delivers more total tokens (1.64x at c=64: 1,099.26 vs 672.18 tok/s).
* **What disaggregation buys at this scale is TTFT p50 flatness under load, not throughput:** disagg TTFT p50 stays at ~554-575 ms from c=8 up while agg climbs 453 → 887, i.e. 1.54x lower at c=64 — but the TTFT tail does not follow (p99 at c=64: disagg 2,979.70 vs agg 2,593.74).
* Both engines were still queue-stable at c=64 (per-phase duration grew ~19% agg / ~6% disagg over c=1 while served tokens grew 64x); the crossover, if one exists for this model on this hardware, sits above c=64 with one 16-GPU replica per side — scaling decode replicas independently is the disagg lever this pair does not exercise.

## PP>1 correctness gate

Hybrid-Mamba models under pipeline parallelism are exposed to a class of KV-transfer bug (vllm-project/vllm#50494) that can produce fluent but wrong output — a latency table cannot catch it. Gate: one greedy completion (`temperature=0`, fixed seed, identical prompt) captured on each live BF16 stack in this campaign, byte-compared against the single-node TP8/PP1 control (`agg/deployment`). The control's completion is byte-identical to the one captured in the 2026-08-18 campaign on a different image build.

| shape | vs PP1 control |
|---|---|
| `agg/lws` (TP8/PP2) | byte-identical |
| `disagg/lws-pp2` (TP8/PP2 both roles) | byte-identical |
| `disagg/deployment` (TP8+TP8, PP1) | byte-identical |
| `agg/lws-ep`, `agg/dgd-grove-ep` (EP16) | byte-identical |
| `disagg/lws-ep` (EP16 both roles) | byte-identical |
| `agg/dgd-grove` (TP8/PP2), `disagg/dgd-grove-pp2` (PP2 both roles) | diverge — but byte-identical to the PP1 `agg/dgd` text |
| `agg/dgd`, `disagg/dgd-grove`, `disagg/dgd-grove-ep` (PP1 shapes; `-ep` adds DP2) | diverge — one shared text |
| `disagg/dgd` (TP8+TP8, PP1) | diverges — third text |

Every PP>1 `lws` shape passes byte-for-byte, which is what makes their ITL rows quotable. The `dgd`/`dgd-grove` family produces a small set of alternative continuations — all coherent, all diverging from the control late in the completion — and critically the two PP>1 Grove shapes reproduce the **PP1** `agg/dgd` text exactly, so their divergence is the known dgd-template effect (first observed 2026-08-17 on `agg/dgd`, a PP1 shape), not a pipeline-parallel corruption signature. Why the dgd-rendered stacks settle on different greedy continuations than the hand-rolled manifests remains the open gate item. (`disagg/lws-2pp`, not deployable this campaign, passed this gate byte-for-byte in the 2026-08-18 campaign on its then-current build.) NVFP4 captures were taken on all eight re-measured NVFP4 stacks; at that precision there is no byte-stable reference across templates (completions pair up rather than agree globally), so the byte-parity gate is quotable for BF16 only.

## Coverage

21 of the 23 template × precision grid cells (14 BF16 templates, including the five `dgd-grove*` variants added since the last table, + 9 NVFP4 templates) were re-measured cold+warm in this campaign. The BF16 cells reproduce their earlier-campaign measures to ~1-6% ITL p50 across days, stacks, template revisions, and image builds; the NVFP4 cells do **not** — every previously-measured NVFP4 template runs slower than its 2026-08-16/17 measure on the then-current image build (~1.5× ITL p50 on the PP1 shapes, ~1.2× on `disagg/lws-pp2` and `disagg/lws-ep`), so cross-precision conclusions should be read as specific to the image build named above. The two holes are BF16 and NVFP4 `disagg/lws-2pp`: on this image build the template's decode pods fail engine init with CUDA out-of-memory during the vLLM sampler warmup (`_dummy_sampler_run`, 1024 dummy requests — the last allocation of an init sequence that ends with <0.5 GiB headroom per GPU), crash-loop re-streaming weights, and never reach Ready within the deployment budget (3 timed attempts per precision). The same template deployed and measured cleanly on the prior image build (those are the † rows above); lowering the decode role's `gpu_memory_utilization` or `max_num_seqs` is the template-side lever to re-fill these cells.

## Newer-image re-verification: `disagg/lws-2pp` OOM fix (1.4.0-patched / vLLM 0.26, 2026-08-26)

The rows above were measured on the 2026-08-14..18 image (vLLM **0.23**). When the fleet moved to
`public.ecr.aws/hpc-cloud/dynamo-vllm-efa:1.4.0-patched` (vLLM **0.26**), the `disagg/lws-2pp` decode
role began OOM-ing at end-of-init and the cell was reported as "gave up" on 2026-08-26. This section
records the fix verified on that newer image; it does **not** replace row 17 (which remains a valid
0.23 result).

**Root cause (source-verified).** The decode role inherited vLLM's default `max_num_seqs=1024`, and
`_dummy_sampler_run` casts the logits to fp32 unconditionally (`sampler.py:96`) → a
`1024 × 131072 vocab × 4B = 512.0 MiB` transient allocated *after* `capture_model` + KV allocation, at
gpu-util 0.98 with ~0.42 GiB/GPU free. The allocation is byte-identical v0.23.0→v0.28.0→main; what
regressed 0.23→0.26 is the *slack* around it, so a template that cleared at 0.97 on 0.23 sits on the
cliff on 1.4.0-patched. vLLM's own OOM handler at this site (`gpu_model_runner.py:6044-6050`) hardcodes
the fix: *lower `max_num_seqs` or `gpu_memory_utilization`.*

**Fix (single variable on the decode role, prefill PP2/8192/0.92 UNCHANGED):**
`--max-num-seqs 16` (512 MiB → 8 MiB, the primary lever) `+ --gpu-memory-utilization 0.97`
`+ --max-model-len 4096`.

**Warm AIPerf row** — same harness, `--concurrency 10`, 100 requests, **`--warmup-request-count 30`**
(so this row is not methodology-matched to the warmup=0 table above — compare to itself, not row 17),
ISL 1024 (stddev 0) / OSL 512, `ignore_eos:true`, seed 42, on `iankouls-nemotron-ultra-validation`
(4× ml.p6-b200):

| precision | template | image | GPUs | TTFT p50 (ms) | TTST p50 (ms) | ITL p50 (ms) | tok/s/user p50 | tok/s total | tok/s per GPU | basis |
|---|---|---|---|---|---|---|---|---|---|---|
| BF16 | `disagg/lws-2pp` (OOM-fix) | 1.4.0-patched (vLLM 0.26) | 32 | 538.46 | 90.74 | 90.79 | 11.01 | 108.38 | 3.39 | raw aiperf export |
| NVFP4 | `disagg/lws-2pp` (OOM-fix) | 1.4.0-patched (vLLM 0.26) | 32 | 1,039.78 | 182.17 | 193.32 | 5.17 | 50.41 | 1.58 | raw aiperf export |

**Both precisions: 100/100 requests completed, 0 errors** (99 success records + 1 length-tie each) —
the single fixed template serves at load on both published checkpoints of the model. BF16 duration
472.39 s; NVFP4 1,015.62 s (NVFP4 is intrinsically slower per token on this model — see the ratio
below).

**BF16** matches the 0.23 row 17 within noise (TTFT p50 538 vs 546, ITL p50 90.8 vs 88.3) — the fix
made the cell *runnable* on the new image without degrading per-token latency.

**NVFP4** serves cleanly (ITL p50 193.32, a tight distribution: max 218.54, only +13% over p50, so the
median is not hold-contaminated). Two things are worth stating honestly and neither is the OOM fix's
doing:
- **NVFP4 is ~2.13× slower per token than BF16 *on this same new image*** (ITL 193.32 vs 90.79), where
  the 0.23 image showed ~1.50× (132.85 vs 88.32). Same-image ratio is the clean comparison; it says the
  vLLM 0.23→0.26 decode regression (tracked separately) hits the NVFP4 path disproportionately. This is
  a **single-run observation**, not a confirmed measured regression — the 0.23 NVFP4 rows used
  `--warmup-request-count 0` while this row excludes 30, so an absolute cross-image delta is not
  methodology-matched. Flagged for a repeat, not quoted as a verdict.
- The OOM fix is precision-agnostic by construction: `--max-num-seqs 16` shrinks the fp32 sampler
  buffer identically (512 MiB → 8 MiB) regardless of weight dtype, and NVFP4 weights (~41 GiB/GPU vs
  BF16's larger footprint) leave *more* KV headroom — NVFP4 reported **Maximum concurrency 1213.11×**
  for 4096 tokens vs BF16's 335.70×. So NVFP4 was never the tighter case; verifying it closes the
  matrix, it does not stress it.

**KV-over-EFA confirmed on both.** BF16: `Num successful transfers=16, Avg MB per transfer=30.41,
Throughput (MB/s)=12313` → **486.6 MB** at **12.3 GB/s**. NVFP4 (clean single request):
`Num successful transfers=16, Avg MB per transfer=30.41, Throughput (MB/s)=13272.3` → the same
**486.6 MB** prefill→decode at **13.3 GB/s**, `Backend LIBFABRIC was instantiated` (sole transport),
`TransferTopology(remote_tp=8, remote_pp=1, remote_block_len=16384)` = real cross-node pull via
`NixlPullConnector`. The B200 EFA devices on this image expose no mlx-style `hw_counters`, so the
per-request vLLM metric is the transport proof. The identical 486.6 MB / 16-transfer signature on both
precisions is expected — KV cache size is set by sequence geometry (block count × block bytes), not
weight dtype. Evidence: `nvfp4-kv-over-efa-proof-20260826T204358Z.log`.

**Blast radius.** 16 of 17 templates in this tree set no `--max-num-seqs` and are latently exposed to
the same 512 MiB warmup buffer; `lws-2pp` crashed first only because it was the sole template at
gpu-util 0.98. The durable fix is a fleet-wide template-hygiene pass adding `--max-num-seqs <N>`
(sized to benchmark concurrency) to every decode/agg role — tracked for PR aws-do-eks#104.

## Disclaimer

The results here are provided for informational purposes only. They are not meant to guarantee best or minimum performance in your own environment. The purpose of this repository is to provide a framework and tooling that enables you to run your own experiments and evaluate performance of the Nemotron 3 Ultra and other models.

