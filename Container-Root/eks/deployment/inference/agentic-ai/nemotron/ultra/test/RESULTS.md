# Nemotron 3 Ultra 550B — measured AIPerf results (B200, 2026-08-14..18)

Benchmark results for every deployment template in this folder's `agg/` and `disagg/` directories, at both published precisions of the model, measured with the harness in this directory (`test-aiperf.sh` for the fixed-concurrency rows, `aiperf-sweep-run.sh` for the sweeps). Numbers marked *raw aiperf export* are parsed from the `profile_export_aiperf.json` that aiperf 0.9.0 wrote for that run — none are transcribed by hand.

Common to every fixed-concurrency row: Input Sequence Length (ISL) 1024 (stddev 0) / Output Sequence Length (OSL) 512 with `ignore_eos:true`, 100 requests, `--concurrency 10`, `--random-seed 42`, `--warmup-request-count 0`, on a SageMaker HyperPod EKS cluster with 4× p6-b200 nodes (8× B200 each). Each row was run twice on the same stack: cold right after the pods went Ready, then again after a warm interval, and the **warm run is the published row**; the cold companion is kept as provenance. Runs carry a `run-meta.json` that records what actually served them (the observed workload kinds and DYN_NAMESPACE).

## Fixed-concurrency comparison (c=10)

| precision | template | GPUs | TTFT p50 (ms) | TTST p50 (ms) | ITL p50 (ms) | tok/s/user p50 | tok/s total | tok/s per GPU | basis |
|---|---|---|---|---|---|---|---|---|---|
| BF16 | `agg/deployment` | 8 | 503.52 | 45.73 | 89.40 | 11.19 | 110.79 | 13.85 | raw aiperf export |
| BF16 | `agg/lws` | 16 | 534.56 | 49.43 | 49.24 | 20.31 | 199.54 | 12.47 | raw aiperf export |
| BF16 | `agg/lws-ep` | 16 | 451.29 | 206.00 | 113.44 | 8.80 | 87.06 | 5.44 | reported table (raw export not retained) |
| BF16 | `agg/dgd` | 8 | 504.94 | 45.02 | 88.44 | 11.31 | 112.21 | 14.03 | raw aiperf export |
| BF16 | `disagg/deployment` | 16 | 561.97 | 90.14 | 89.84 | 11.13 | 109.90 | 6.87 | raw aiperf export |
| BF16 | `disagg/dgd` | 16 | 552.83 | 90.34 | 88.68 | 11.28 | 110.62 | 6.91 | raw aiperf export |
| BF16 | `disagg/lws-2pp` | 32 | 546.13 | 88.22 | 88.32 | 11.32 | 110.94 | 3.47 | raw aiperf export |
| BF16 | `disagg/lws-ep` | 32 | 704.28 | 114.58 | 114.58 | 8.73 | 78.98\* | 2.47\* | raw aiperf export |
| BF16 | `disagg/lws-pp2` | 32 | 356.81 | 49.88 | 49.93 | 20.03 | 196.46 | 6.14 | raw aiperf export |
| NVFP4 | `agg/deployment` | 8 | 431.14 | 152.26 | 122.81 | 8.14 | 46.25\* | 5.78\* | raw aiperf export |
| NVFP4 | `agg/lws` | 16 | 462.53 | 65.07 | 72.08 | 13.88 | 51.82\* | 3.24\* | raw aiperf export |
| NVFP4 | `agg/dgd` | 8 | 452.02 | 125.42 | 127.01 | 7.87 | 78.14 | 9.77 | raw aiperf export |
| NVFP4 | `disagg/deployment` | 16 | 766.09 | 122.90 | 127.66 | 7.84 | 56.66 | 3.54 | reported table (raw export not retained) |
| NVFP4 | `disagg/dgd` | 16 | 785.43 | 124.52 | 125.39 | 7.97 | 70.42 | 4.40 | raw aiperf export |
| NVFP4 | `disagg/lws-2pp` | 32 | 742.68 | 123.78 | 132.85 | 7.53 | 47.36\* | 1.48\* | raw aiperf export |
| NVFP4 | `disagg/lws-ep` | 32 | 1,145.46 | 163.45 | 229.46 | 4.36 | 37.08\* | 1.16\* | raw aiperf export |
| NVFP4 | `disagg/lws-pp2` | 32 | 482.86 | 66.19 | 87.89 | 11.38 | 58.11\* | 1.82\* | raw aiperf export |

\* total-throughput columns contaminated by stalls in the run's wall clock — see the caveats below.

### How to read this table

1. **Compare on ITL p50 and TTFT p50.** At fixed concurrency and pinned output length there is essentially one independent latency number per row: tok/s/user ≈ 1000/ITL and total ≈ that × concurrency, so quoting all columns is quoting ITL several times.
2. **No fixed-concurrency row is a throughput result.** c=10 is latency-bound, nowhere near saturation; the sweeps below are the throughput data.
3. **Tails need repeats.** Most rows are n=1 at 100 requests; p90/p99/max on such a run can be a single request.
4. **Cross-precision comparisons must hold the template fixed.** The same-shape pairs measured here: `agg/dgd` BF16 88.44 vs NVFP4 127.01 ITL p50 (1.44x), `agg/deployment` 89.40 vs 122.81 (1.37x), `agg/lws` 49.24 vs 72.08 (1.46x) — BF16 is consistently faster per token on B200 for this model.
5. **PP2 is the latency lever.** The two TP8/PP2 shapes (`agg/lws`, `disagg/lws-pp2`) run ITL ~49-50 ms vs ~88-90 ms for every TP8/PP1 shape at BF16 — and the PP>1 correctness gate below is what makes those rows quotable.

### Caveats measured on the 2026-08-17/18 cold+warm pairs

* **BF16 TTFT tails are a cold-engine effect and a warm run removes them** (5 of 5 pairs): `agg/deployment` p95 1,335.30 → 537.01, `agg/dgd` p95 1,256.81 → 520.57 (max within 16 ms of p50), `disagg/lws-pp2` p95 2,559.29 → 805.74, and on 2026-08-18 `disagg/lws-2pp` p95 6,213.13 → 980.03 and `disagg/deployment` p95 1,628.61 → 995.73 — while ITL p50 and total tok/s moved <1%. The cold tail is the opening concurrency wave paying JIT, not steady-state degradation. What the warm disagg rows keep is a confined top-decile TTFT step (p95≈max at ~1.8x p50), not a multi-second tail.
* **NVFP4 aggregated TTFT tails are NOT cold-engine** (2 of 2 pairs got *worse* warm: `agg/lws` p95 315.3 s cold → 503.0 s warm; `agg/deployment` 116.4 s → 182.2 s). These are multi-minute holds that recur mid-run — the class `aiperf-clean-tail.sh` exists to separate — so on those two rows every column above p50 describes the holds, and the starred totals understate the warm rate. NVFP4 `disagg/dgd` did clean up warm (p95 321 s → 1.13 s).

## Concurrency sweeps: aggregated vs disaggregated at equal GPU count

Both sweeps are the same experiment as the table above (ISL 1024 / OSL 512, ignore_eos, seed 42, aiperf 0.9.0) with only concurrency varying — c = 1/4/8/16/32/64, 20 waves per phase, and a per-phase excluded warm-up (2 waves + 1). Because the warm-up is excluded, sweep rows are not directly comparable to the warmup=0 table rows; compare sweep to sweep. The pair holds GPU count fixed at 16: `agg/lws` (aggregated TP8/PP2 spanning 2 nodes) vs `disagg/deployment` (prefill TP8 + decode TP8, one node each).

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

Hybrid-Mamba models under pipeline parallelism are exposed to a class of KV-transfer bug (vllm-project/vllm#50494) that can produce fluent but wrong output — a latency table cannot catch it. Gate: one greedy completion (`temperature=0`, fixed seed, identical prompt) captured on each live BF16 stack, byte-compared against the single-node TP8/PP1 control (`agg/deployment`).

| shape | vs PP1 control |
|---|---|
| `agg/lws` (TP8/PP2) | byte-identical |
| `disagg/lws-pp2` (TP8/PP2 both roles) | byte-identical |
| `disagg/deployment` (TP8+TP8, PP1) | byte-identical |
| `disagg/lws-2pp` (prefill TP8/PP2 + 2× decode TP8/PP1) | byte-identical |

Every checked PP>1 shape in the table above passes, which is what makes their ITL rows quotable. 

## Disclaimer

The results here are provided for informational purposes only. They are not meant to guarantee best or minimum performance in your own environment. The purpose of this repository is to provide a framework and tooling that enables you to run your own experiments and evaluate performance of the Nemotron 3 Ultra and other models.

