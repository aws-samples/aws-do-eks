# Disaggregation Calculator — agg vs. disagg decision tool for LLM serving

Quick Start: [bit.ly/aws-calc-disagg](https://bit.ly/aws-calc-disagg)

Author: Anton Alexander

> **Disclaimer.** This calculator is provided **free of charge, as a utility** to help quickly
> **estimate** and plan model-serving topologies. It produces **first-order estimates and guidance only**.
> AWS and the authors make **no representation, warranty, or guarantee** — express or implied — about model
> performance, throughput, latency, cost, or fitness for any purpose, and **accept no liability** for any
> outcome arising from its use. Actual measured results will differ from the calculated numbers. Always
> validate on your own hardware with your own workload before making deployment or purchasing decisions.
> The calculator is provided **"AS IS"** without support obligation.

An architecture-first calculator that answers a single question for any model on any GPU:
**should I serve it aggregated (prefill + decode on one worker) or disaggregated (prefill and decode
split across workers, KV cache moved over the network)?** It derives the answer from the model's real
architecture (`config.json`), the GPU's HBM and bandwidth, and your workload (input/output token lengths,
SLO), then reports the memory fit, the predicted TTFT/ITL/throughput, the $/Mtok, and the verdict.

It is the planning companion to the [NVIDIA Nemotron 3 Ultra 550B](../nemotron/ultra) deployment in this
project: use the calculator to pick a topology, then deploy it with the `agg` / `disagg` manifests there.

To stay aligned with the principles of the [do-framework](https://bit.ly/do-framework), this tool is pure
Python standard library (no install) plus two static HTML pages (no server) — clone and run.

## What's here

```
disagg-calculator/
  analyze/
    calc.py          # the engine — architecture-aware agg/disagg math + verdict (CLI + importable)
    calibration.py   # PREDICT → MEASURE → DELTA loop; corrects the math toward live-measured numbers
  results/
    calibration/
      ledger.jsonl   # append-only measured datapoints the calculator calibrates against (seeded on p5en)
  web/
    index.html       # interactive calculator (pick a model + GPU + workload → verdict), runs in-browser
    calculator.html  # the same engine as a single-purpose page (shareable link)
  docs/
    DEPLOYMENT-GUIDE.md  # when to disaggregate vs. scale aggregated replicas — rules of thumb + worked cases
    METHODOLOGY.md       # the math, the physics assumptions, and how the calibration loop refines them
```

> **Engine = two files.** `calc.py` lazily imports `calibration.py`; without it the calculator silently
> falls back to the uncalibrated HBM-roofline numbers (e.g. decode ITL ~4 ms instead of the live-measured
> ~80 ms). Always ship/run them together. `ledger.jsonl` is the measured data they calibrate against.

## Prerequisites

- Python 3.9+ (standard library only — nothing to `pip install`).
- For the web pages: any modern browser. No server, no build step.

## Run (CLI)

From the `aws-do-eks` shell (or any shell with Python 3):

```bash
cd /eks/deployment/inference/agentic-ai/disagg-calculator/analyze

# Self-test (proves the engine + calibration are wired correctly):
python3 calc.py --selftest

# Score a model from its HuggingFace config.json on a given GPU + workload:
python3 calc.py --config /path/to/config.json --gpu p5en --isl 8192 --osl 1024 --tp 8 --pp 1
```

The output JSON includes the memory fit (weights + KV vs. HBM), the predicted timings
(`prefill_compute`, `kv_transfer`, `decode_step_ITL`), the $/Mtok for agg vs. disagg, and the verdict
(`aggregate` / `disaggregate` / `no-op`) with the reasoning.

## Run (web)

Open `web/index.html` in a browser (or serve the `web/` folder statically). Pick a model preset (or paste a
`config.json`), choose the GPU and workload, and read the verdict. `web/calculator.html` is the same engine
as a single shareable page. The browser pages mirror `analyze/calc.py` exactly — a parity harness in the
source project asserts they agree on a model × workload grid, so the link you share computes what the CLI does.

You can directly use the following [link](https://rawcdn.githack.com/aws-samples/aws-do-eks/refs/heads/main/Container-Root/eks/deployment/inference/agentic-ai/disagg-calculator/web/index.html)
or this short-link: [https://bit.ly/aws-calc-disagg](https://bit.ly/aws-calc-disagg)

## How it stays honest (calibration)

First-order math over-predicts throughput and under-predicts latency for hybrid (Mamba + attention) models —
a naive HBM roofline says "fast" while the live system is decode-latency-bound. `calibration.py` records what
we **predicted**, ingests what we **measured** on real GPUs (the seed datapoint is Nemotron-3 Ultra 550B on
p5en/H200), computes the **delta**, and derives a per-(family, metric) **correction factor**. As more live
runs land in `results/calibration/ledger.jsonl`, the corrections converge and the calculator gets more
accurate **without changing the physics**. See [docs/METHODOLOGY.md](docs/METHODOLOGY.md).

## When to use which verdict

See [docs/DEPLOYMENT-GUIDE.md](docs/DEPLOYMENT-GUIDE.md) for the rules of thumb. In short:

- **Aggregated replicas** when: short-context chat, prefill cheap relative to decode, cost/throughput-bound,
  loose-to-moderate ITL SLO. At the 1P:1D floor, disaggregation buys little but costs ≥2× the GPUs.
- **Disaggregate** when: long input contexts (RAG / agents / code), prefill-heavy, tight TPOT/ITL SLO, and you
  can right-size the prefill : decode pool ratio (asymmetric scaling via independent replica counts).

## References

- [do-framework](https://bit.ly/do-framework) · [aws-do-eks](https://bit.ly/do-eks)
- Companion deployment: [Nemotron 3 Ultra 550B](../nemotron/ultra) (agg + disagg manifests)
- [NVIDIA Dynamo](https://github.com/ai-dynamo/dynamo) · [NIXL](https://github.com/ai-dynamo/nixl)
