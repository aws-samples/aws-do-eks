#!/usr/bin/env python3
"""
Author: Anton Alexander

calibration.py — close the loop: PREDICT → MEASURE → DELTA → CORRECTION-FACTOR, refined over time.

The calculators (calc.py / optimizer.py) make first-order predictions. This records what we PREDICTED, ingests
what we MEASURED on real GPUs, computes the DELTA (ratio measured/predicted), and derives a per-(family,metric)
**correction factor** = the median measured/predicted across every datapoint in the ledger. As more live runs
land (the staged optimize/queue experiments), the ledger grows and the correction factors converge — the
calculator gets more accurate over time without changing the physics.

Seed datapoint (the one cell we have MEASURED, this session, on cgk p5en):
  Nemotron-3-Ultra-550B / p5en / ISL512-OSL128:
    decode ITL : predicted 4.4 ms (HBM roofline floor) vs MEASURED ~82 ms  → ratio ~18.6x
      (the eager-mode + hybrid-Mamba + concurrency-1 penalty — real MBU ~0.04, not the 0.65 roofline)
    peak tok/s : MEASURED 292 (optimized knee) ; goodput knee : MEASURED concurrency 32
    $/Mtok     : MEASURED $95.88 (agg) vs $202.71 (disagg)
The ITL ratio is the single most important correction — it's why a naive roofline says "hybrid/fast" while the
live system is decode-latency-bound. correction_factor('hybrid-mamba','itl') returns it; apply_correction()
scales a raw prediction by it.

Ledger = results/calibration/ledger.jsonl (append-only, one record/line; survives across sessions). Pure stdlib.
"""
from __future__ import annotations
import argparse, json, os, sys, statistics

HERE = os.path.dirname(os.path.abspath(__file__))
LEDGER = os.path.join(HERE, "..", "results", "calibration", "ledger.jsonl")

# The seed records (MEASURED this session). add_measurement() appends more as live runs complete.
SEED = [
    {"model": "nemotron-ultra-550b", "family": "hybrid-mamba", "instance": "p5en.48xlarge",
     "isl": 512, "osl": 128, "metric": "itl_ms", "predicted": 4.4, "measured": 82.0,
     "source": "study/RESULT.md + optimize/RESULT-optimization.md (live A/B + deep ramp)", "date": "2026-06-14"},
    {"model": "nemotron-ultra-550b", "family": "hybrid-mamba", "instance": "p5en.48xlarge",
     "isl": 512, "osl": 128, "metric": "peak_tok_s", "predicted": None, "measured": 292.0,
     "source": "optimize/RESULT-optimization.md deep ramp (optimized knee)", "date": "2026-06-14"},
    {"model": "nemotron-ultra-550b", "family": "hybrid-mamba", "instance": "p5en.48xlarge",
     "isl": 512, "osl": 128, "metric": "goodput_knee_concurrency", "predicted": 32, "measured": 32,
     "source": "optimize/RESULT-optimization.md (optimizer predicted 32, ramp measured 32)", "date": "2026-06-14"},
    {"model": "nemotron-ultra-550b", "family": "hybrid-mamba", "instance": "p5en.48xlarge",
     "isl": 512, "osl": 128, "metric": "usd_per_mtok_agg", "predicted": 107.6, "measured": 95.88,
     "source": "cost.py est vs measured-goodput live A/B", "date": "2026-06-14"},
    {"model": "nemotron-ultra-550b", "family": "hybrid-mamba", "instance": "p5en.48xlarge",
     "isl": 512, "osl": 128, "metric": "kv_MB_per_req", "predicted": 247.5, "measured": 486.0,
     "source": "calc.py est vs measured host-level rdma_read_bytes delta", "date": "2026-06-13"},
]


def _read():
    rows = list(SEED)
    if os.path.isfile(LEDGER):
        for ln in open(LEDGER):
            ln = ln.strip()
            if ln:
                try:
                    rows.append(json.loads(ln))
                except Exception:
                    pass
    return rows


def add_measurement(model, family, instance, isl, osl, metric, predicted, measured, source, date):
    """Append a measured datapoint to the ledger (the queued live runs call this with their results)."""
    os.makedirs(os.path.dirname(LEDGER), exist_ok=True)
    rec = {"model": model, "family": family, "instance": instance, "isl": isl, "osl": osl,
           "metric": metric, "predicted": predicted, "measured": measured, "source": source, "date": date}
    with open(LEDGER, "a") as f:
        f.write(json.dumps(rec) + "\n")
    return rec


def delta(rows=None):
    """Per record: ratio = measured/predicted (the correction needed). None predicted = measurement-only."""
    rows = rows if rows is not None else _read()
    out = []
    for r in rows:
        p, m = r.get("predicted"), r.get("measured")
        ratio = (m / p) if (p not in (None, 0) and m is not None) else None
        out.append({**r, "ratio_measured_over_predicted": round(ratio, 3) if ratio else None,
                    "abs_delta": round(m - p, 2) if (p is not None and m is not None) else None})
    return out


def correction_factor(family, metric, rows=None):
    """The correction = median(measured/predicted) over all ledger rows for (family, metric). 1.0 = perfect;
    >1 = we UNDER-predict (e.g. ITL), <1 = we over-predict. Used by apply_correction()."""
    rows = rows if rows is not None else _read()
    ratios = [r["measured"] / r["predicted"] for r in rows
              if r.get("family") == family and r.get("metric") == metric
              and r.get("predicted") not in (None, 0) and r.get("measured") is not None]
    if not ratios:
        return {"factor": 1.0, "n": 0, "confidence": "none (no measured data — raw prediction unadjusted)"}
    return {"factor": round(statistics.median(ratios), 3), "n": len(ratios),
            "spread": [round(min(ratios), 3), round(max(ratios), 3)],
            "confidence": "low (n=1)" if len(ratios) == 1 else f"n={len(ratios)}"}


def apply_correction(predicted, family, metric):
    """Scale a raw prediction by the learned correction factor. Returns (corrected, factor_info)."""
    cf = correction_factor(family, metric)
    return (round(predicted * cf["factor"], 3) if predicted is not None else None), cf


def report(rows=None):
    rows = delta(rows)
    fams = sorted({(r["family"], r["metric"]) for r in rows if r.get("predicted") is not None})
    factors = {f"{fam}/{met}": correction_factor(fam, met) for fam, met in fams}
    return {"n_records": len(rows), "ledger_path": LEDGER, "records": rows, "correction_factors": factors,
            "note": ("Correction = median(measured/predicted). It refines as live runs append. The big one: "
                     "hybrid-mamba ITL ~18x (eager + concurrency-1) — apply it and the calculator's latency "
                     "prediction matches the measured 550B. As the queued long-context / 2nd-model runs land, "
                     "more families gain factors and confidence rises.")}


def _selftest():
    rows = _read()
    # seed must be present + the ITL correction must reflect the ~18x measured-vs-predicted gap
    cf = correction_factor("hybrid-mamba", "itl_ms")
    assert cf["n"] >= 1, cf
    assert 15 <= cf["factor"] <= 22, cf            # measured 82 / predicted 4.4 = 18.6
    # apply_correction lifts the 4.4ms roofline toward the measured 82ms
    corrected, info = apply_correction(4.4, "hybrid-mamba", "itl_ms")
    assert 70 <= corrected <= 100, (corrected, info)
    # knee correction = 1.0 (predicted 32 == measured 32 — the optimizer nailed it)
    knee = correction_factor("hybrid-mamba", "goodput_knee_concurrency")
    assert abs(knee["factor"] - 1.0) < 1e-6, knee
    # a family+metric with NO data returns the identity factor (no silent fabrication). Use a sentinel that
    # can never appear in the ledger, so this stays true as real measured points (e.g. dense itl 0.887x) are
    # appended over time — do NOT hardcode a real family here.
    none_cf = correction_factor("__nonexistent_family__", "itl_ms")
    assert none_cf["factor"] == 1.0 and none_cf["n"] == 0, none_cf
    # if a dense ITL point has been measured (live 70B A/B), it must be a sane near-1.0 correction (not absurd)
    dense_cf = correction_factor("dense", "itl_ms")
    if dense_cf["n"] >= 1:
        assert 0.3 <= dense_cf["factor"] <= 3.0, dense_cf   # dense roofline ~tracks reality; measured 0.887x
    print(f"calibration.py selftest PASS — {len(rows)} ledger records; hybrid-mamba ITL correction "
          f"={cf['factor']}x ({cf['confidence']}) → corrects 4.4ms roofline to {corrected}ms (measured 82); "
          f"knee correction {knee['factor']}x (optimizer nailed it); "
          f"dense/itl n={dense_cf['n']} factor={dense_cf['factor']}; nonexistent-family → identity 1.0")
    return 0


def main():
    ap = argparse.ArgumentParser(description="Calibration ledger: predicted→measured→delta→correction-factor")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--add", nargs=9, metavar=("MODEL", "FAMILY", "INSTANCE", "ISL", "OSL", "METRIC", "PRED", "MEAS", "SOURCE"),
                    help="append a measured datapoint (date stamped today by the caller via SOURCE)")
    ap.add_argument("--out")
    a = ap.parse_args()
    if a.selftest:
        sys.exit(_selftest())
    if a.add:
        model, fam, inst, isl, osl, met, pred, meas, src = a.add
        rec = add_measurement(model, fam, inst, int(isl), int(osl), met,
                              float(pred) if pred not in ("None", "-") else None, float(meas), src, "appended")
        print("added:", json.dumps(rec)); return 0
    rep = report()
    js = json.dumps(rep, indent=2)
    if a.out: open(a.out, "w").write(js)
    print(js)
    print("\n=== correction factors (median measured/predicted) ===", file=sys.stderr)
    for k, v in rep["correction_factors"].items():
        print(f"  {k:48s} {v['factor']}x  ({v['confidence']})", file=sys.stderr)


if __name__ == "__main__":
    sys.exit(main())
