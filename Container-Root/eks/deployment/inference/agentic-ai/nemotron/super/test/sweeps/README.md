# Concurrency-sweep charts (H200, 2026-10-13)

Built with matplotlib from the per-phase `profile_export_aiperf.json` of two `aiperf-sweep.yaml-template` runs (aiperf 0.9.0), one server launch per cell, read after validation (request_count = 20c, 0 errors, warm-up 2c+1 excluded, ISL 1024/OSL 512/seed 42): x = `output_token_throughput.avg` (tok/s), left y = `time_to_first_token.avg` (ms), right y = `inter_token_latency.avg` (ms/token), one point per phase c = 1/2/4/8/16/32/64/128. Source bundles: BF16 `agg/deployment` sweep run id 20261013T044819Z (window 20261013T043719Z) and BF16 `disagg/deployment` sweep run id 20261013T045417Z (window 20261013T043724Z); the numbers are in the tables of `../RESULTS.md` ("Concurrency sweeps"), footnotes 6 and 7.

| file | what |
|---|---|
| `sweep-agg.png` | BF16 agg/deployment, TTFT avg + ITL avg vs output tok/s |
| `sweep-disagg.png` | BF16 disagg/deployment, same axes |
| `sweep-overlay-agg-vs-disagg.png` | both cells on one pair of axes (8 vs 16 GPUs: not an equal-GPU comparison) |
| `sweep-throughput-scaling.png` | output tok/s vs concurrency (log2) for both cells |
