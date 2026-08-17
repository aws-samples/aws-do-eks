#!/usr/bin/env python3
"""Split an aiperf profile_export.jsonl into its stalled tail and its steady state.

WHY THIS EXISTS
A disagg run on this stack does not produce one population of requests. Two runs on
p6-b200 (2026-08-16, Nemotron-3-Ultra-550B-A55B-NVFP4, 100 requests @ --concurrency 10,
ISL 1024 / OSL 512, 0 errors) both released batches of requests at single instants
(counts at this script's default cutoff of TTFT > 5000ms):

  disagg/lws-pp2  20 of 100 requests, first tokens clustered at t=229.2-229.5s (10)
                                                            and t=461.8-462.2s (10)
  disagg/lws-ep   16 of 100 requests, first tokens at t=92.96s (6) and t=311.24s (8),
                                      plus singletons at t=143.5s and t=734.9s

A count is a function of the cut, so state the cutoff whenever you quote one - the same
lws-ep export read at TTFT > 2000ms is 23 of 100 rather than 16.

Inside each instant the first-token timestamps agree to under a millisecond, which a
queue cannot produce - a queue staggers. The prefill worker log for the lws-ep run shows
what those requests were doing: held in the running set with "Avg prompt throughput:
0.0 tokens/s, Waiting: 0 reqs, GPU KV cache usage: 0.2%" for ~70s, then a burst at
311-415 tokens/s that hands the whole group off at once. So the wait is upstream of
decode, it is not a queue, and it is not memory pressure.

The consequence for reporting: with 16 of 100 requests stalled, aiperf reports TTFT
avg 12,295ms / p90 54,193ms / p99 92,963ms against a p50 of 1,145ms. The mean and the
upper percentiles describe the stall, not the serving path, and they are not comparable
between two runs that stalled a different number of times. The steady-state percentiles
are comparable. Report both, separately, and say how many requests stalled.

WHAT THIS IS NOT
It is not a substitute for the warmup phase test-aiperf.sh runs. That phase prevents the
class of hold confined to the OPENING concurrency wave, at the source: on the BF16
disagg/lws-ep run of 2026-08-17T06:01:40Z all 10 slow requests (TTFT > 2000ms) were the
10 issued at t=0, and excluding them moves TTFT p50 704.28 -> 703.28ms and leaves ITL p50
at 114.58ms - under 0.2%, so there is nothing for a post-hoc split to recover. This script
is for the class that RECURS mid-run, which no warmup can remove: on the NVFP4 lws-ep
export above, 13 of the 23 slow requests were ISSUED between t=136.5s and t=729.6s, long
after any warmup phase has ended.

USAGE
  ./aiperf-clean-tail.sh <artifact-dir>/profile_export.jsonl [ttft_cutoff_ms]

A cutoff of 5000ms is far above every steady-state TTFT observed on this model
(max 4,065ms over 84 clean requests) and far below every stalled one (min 5,346ms).
Raise it if your model's warm TTFT is genuinely slower than 5s.
"""
import json
import statistics as st
import sys


def pct(values, q):
    ordered = sorted(values)
    if len(ordered) < 3:
        return float("nan")
    return st.quantiles(ordered, n=100)[q - 1]


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    path = sys.argv[1]
    cutoff = float(sys.argv[2]) if len(sys.argv) > 2 else 5000.0

    rows = [json.loads(line) for line in open(path) if line.strip()]
    if not rows:
        sys.exit(f"{path}: no records (an aiperf run that was still writing, or overwritten)")
    origin = min(r["metadata"]["request_start_ns"] for r in rows)
    last = max(r["metadata"]["request_end_ns"] for r in rows)

    recs = []
    for idx, r in enumerate(rows):
        m = r["metrics"]
        recs.append({
            "idx": idx,
            "start_s": (r["metadata"]["request_start_ns"] - origin) / 1e9,
            "ttft": m["time_to_first_token"]["value"],
            "ttst": m["time_to_second_token"]["value"],
            "itl": m["inter_token_latency"]["value"],
            "latency_s": m["request_latency"]["value"] / 1000.0,
            "tps_per_user": m["output_token_throughput_per_user"]["value"],
            "osl": m["output_sequence_length"]["value"],
        })

    stalled = [r for r in recs if r["ttft"] > cutoff]
    steady = [r for r in recs if r["ttft"] <= cutoff]
    span_s = (last - origin) / 1e9
    tokens = sum(r["osl"] for r in recs)

    print(f"{path}")
    print(f"  requests {len(recs)}  phase {span_s:.1f}s  output tokens {tokens}"
          f"  aggregate {tokens / span_s:.2f} tok/s")
    print(f"  stalled (TTFT > {cutoff:.0f}ms) {len(stalled)}   steady {len(steady)}")

    if stalled:
        print(f"\n  STALLED - grouped by the instant the first token arrived")
        print(f"  {'request':>8} {'started_s':>10} {'ttft_ms':>12} {'first_token_at_s':>17}")
        for r in sorted(stalled, key=lambda r: r["start_s"] + r["ttft"] / 1000.0):
            print(f"  {r['idx']:>8} {r['start_s']:>10.2f} {r['ttft']:>12.2f}"
                  f" {r['start_s'] + r['ttft'] / 1000.0:>17.2f}")
        print("  Timestamps that agree to the millisecond are one release, not a queue.")
        print("  Check the prefill worker for that wall-clock window before reporting a")
        print("  TTFT mean: kubectl logs <prefill-pod> | grep -E 'prompt throughput|shm_broadcast'")

    if steady:
        print(f"\n  STEADY STATE over {len(steady)} requests")
        print(f"  {'metric':<16} {'min':>10} {'p50':>10} {'p90':>10} {'max':>10}")
        for key, label in (("ttft", "ttft_ms"), ("ttst", "ttst_ms"), ("itl", "itl_ms"),
                           ("latency_s", "latency_s"), ("tps_per_user", "tok/s/user")):
            v = [r[key] for r in steady]
            print(f"  {label:<16} {min(v):>10.2f} {st.median(v):>10.2f}"
                  f" {pct(v, 90):>10.2f} {max(v):>10.2f}")
        ideal = st.median([r["latency_s"] for r in steady]) * len(recs) / 10.0
        print(f"\n  A run of {len(recs)} requests at concurrency 10 that never stalled would")
        print(f"  take about {ideal:.0f}s at this steady-state latency; this one took"
              f" {span_s:.0f}s ({100 * (span_s - ideal) / span_s:.0f}% lost).")
        print("  Adjust the divisor if you did not run --concurrency 10.")


if __name__ == "__main__":
    main()
