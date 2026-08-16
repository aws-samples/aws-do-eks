#!/usr/bin/env python3
"""Report whether a disagg run served requests on KV blocks the producer had freed.

WHY THIS EXISTS
In vLLM's NixlConnector the PREFILL side holds a request's KV blocks under a lease and
frees them when it elapses (nixl/worker.py: get_from_extra_config("kv_lease_duration",
30) - the default is 30 seconds). Two things then happen in the prefill worker's log:

  WARNING "Releasing expired KV blocks for request <id> which were retrieved by
           0 remote worker(s) before lease expired."
  ERROR   "Potentially invalid KV blocks for unrecognized request <id> were retrieved
           by a decode worker. They may have expired."

The second one is only logged. The code path is `logger.error(...); continue` - the
request is not failed, the decode worker keeps whatever it read, and the client still
gets HTTP 200. So a run can be silently wrong while every metric says it passed, which
is why this needs a checker rather than an eyeball.

MEASURED 2026-08-16, live 3-Pod disagg/dgd run (Nemotron-3-Ultra-550B-A55B-NVFP4,
p6-b200, prefill and decode on different nodes, 42 completed requests): 8 of those 42
produced BOTH lines, each once per prefill TP rank (8/8, so 64 log lines per message),
and all 8 returned 200. The lease was the stock 30s; the gap between decode receiving
the request and the KV being pulled measured 50-62s, always past it.

USAGE
  ./kv-lease-check.sh                      # every prefill Pod of $DEPLOYMENT_NAME
  ./kv-lease-check.sh <prefill-worker.log> # a log you already saved

Exit status is 0 when no request lost its lease and 1 when one did, so it can gate a
benchmark. A clean log from a run that served nothing proves nothing: the report prints
the peak prompt throughput it saw so an idle window cannot read as a pass.
"""
import re
import statistics as st
import sys
from datetime import datetime

ANSI = re.compile(r"\x1b\[[0-9;]*m")
# vLLM worker lines carry their own MM-DD HH:MM:SS stamp and a (Worker_TPn pid=...) prefix.
RELEASED = re.compile(
    r"(?:\(Worker_TP(?P<rank>\d+)[^)]*\)\s*)?WARNING (?P<ts>\d\d-\d\d \d\d:\d\d:\d\d)"
    r".*Releasing expired KV blocks for request (?P<req>\S+) which were retrieved by "
    r"(?P<reads>\d+) remote worker"
)
LATE_READ = re.compile(
    r"(?:\(Worker_TP(?P<rank>\d+)[^)]*\)\s*)?ERROR (?P<ts>\d\d-\d\d \d\d:\d\d:\d\d)"
    r".*unrecognized request (?P<req>\S+) were retrieved by a decode worker"
)
# The engine's own stats line, from Dynamo's logger, ISO stamp and no TP prefix.
THROUGHPUT = re.compile(r"Avg prompt throughput: (?P<tps>[\d.]+) tokens/s")


def stamp(text):
    # No year in a vLLM worker stamp; a fixed one is fine, only deltas are used.
    return datetime.strptime("2000-" + text, "%Y-%m-%d %H:%M:%S")


def main():
    paths = sys.argv[1:]
    if not paths:
        sys.exit(__doc__)

    released = {}   # req -> {"ts": first stamp, "reads": max count, "ranks": set}
    late_read = {}  # req -> {"ts": first stamp, "ranks": set}
    peak_tps = 0.0
    lines = 0

    for path in paths:
        try:
            handle = sys.stdin if path == "-" else open(path, errors="replace")
        except OSError as err:
            sys.exit(f"{path}: {err}")
        for raw in handle:
            lines += 1
            line = ANSI.sub("", raw)
            if m := THROUGHPUT.search(line):
                peak_tps = max(peak_tps, float(m.group("tps")))
                continue
            for pattern, table in ((RELEASED, released), (LATE_READ, late_read)):
                if not (m := pattern.search(line)):
                    continue
                req = m.group("req")
                entry = table.setdefault(req, {"ts": stamp(m.group("ts")), "ranks": set()})
                entry["ts"] = min(entry["ts"], stamp(m.group("ts")))
                if m.group("rank") is not None:
                    entry["ranks"].add(int(m.group("rank")))
                if pattern is RELEASED:
                    entry["reads"] = max(entry.get("reads", 0), int(m.group("reads")))
                break

    if not lines:
        sys.exit("no log content on stdin or in the given files")

    unread = {r: e for r, e in released.items() if e["reads"] == 0}
    served_on_freed = sorted(set(released) & set(late_read),
                             key=lambda r: released[r]["ts"])
    orphan_reads = sorted(set(late_read) - set(released))
    ranks = sorted({rank for e in list(released.values()) + list(late_read.values())
                    for rank in e["ranks"]})

    print(" ".join(paths))
    print(f"  lines read {lines}   peak prompt throughput {peak_tps:.1f} tok/s"
          f"   prefill TP ranks reporting {len(ranks)}"
          + (f" (TP{ranks[0]}..TP{ranks[-1]})" if ranks else ""))
    print(f"  leases expired {len(released)}   of those with 0 reads {len(unread)}"
          f"   later read anyway {len(served_on_freed)}")

    if served_on_freed:
        gaps = []
        print(f"\n  SERVED ON FREED KV - the producer released these, then a decode"
              f" worker read them")
        print(f"  {'request':<46} {'expired':>9} {'reads':>6} {'late_read':>10} {'gap_s':>7}")
        for req in served_on_freed:
            gap = (late_read[req]["ts"] - released[req]["ts"]).total_seconds()
            gaps.append(gap)
            expired_at = released[req]["ts"].strftime("%H:%M:%S")
            read_at = late_read[req]["ts"].strftime("%H:%M:%S")
            print(f"  {req[:46]:<46} {expired_at:>9} {released[req]['reads']:>6}"
                  f" {read_at:>10} {gap:>7.0f}")
        clean = [g for g in gaps if g >= 0]
        if clean:
            print(f"  expired -> late read (s): min {min(clean):.0f}"
                  f"  median {st.median(clean):.0f}  max {max(clean):.0f}")
            print(f"  Every one of these requests still returned 200 to its client.")

    if orphan_reads:
        print(f"\n  {len(orphan_reads)} late read(s) with no matching release in these"
              f" logs - a producer\n  restart or a rotated log, not necessarily a"
              f" different fault:")
        for req in orphan_reads[:10]:
            print(f"    {req}")

    if unread:
        print(f"\nFAIL: {len(unread)} request(s) had their KV lease expire with 0 reads.")
        print("  Raise the lease past the longest hold this shape produces:")
        print("    ../disagg/.env -> KV_LEASE_DURATION (default 300, vLLM's own is 30)")
        print("  Set it once: every template in ../disagg passes it to BOTH roles, and")
        print("  two other timings derive from it - the producer's extension per")
        print("  heartbeat (2/3 of it) and the decode side's heartbeat interval (1/6 of")
        print("  it) - so a value on only one role desynchronises them.")
        print("  Containment, not a cure: the reason decode took that long to pull is a")
        print("  separate question, and the lease only stops it corrupting the answer.")
        sys.exit(1)

    if released:
        print(f"\nPASS with a caveat: {len(released)} lease(s) expired, but each had"
              f" already been read.")
        print("  Blocks were freed on schedule after their consumer was done.")
        sys.exit(0)

    print("\nPASS: no KV lease expired in these logs.")
    if peak_tps == 0.0:
        print("  Peak prompt throughput was 0 tok/s though - this log may not cover a")
        print("  window where anything was actually served. Re-check after a benchmark.")
    sys.exit(0)


if __name__ == "__main__":
    main()
