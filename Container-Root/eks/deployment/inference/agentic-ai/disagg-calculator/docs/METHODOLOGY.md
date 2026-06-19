# Methodology: deciding aggregation vs disaggregation, and finding the optimal settings — for ANY model on ANY compute

*Author: Anton Alexander*  
*Source: github.com/dmvevents/dynamo-disagg-optimizer · live: dmvevents.github.io/dynamo-disagg-optimizer/calculator.html*


A **repeatable, model-agnostic, hardware-agnostic, engine-agnostic** process. Plug in a model (its HF
`config.json`), a compute target (GPU instance), a serving engine (any OpenAI-compatible endpoint), an SLA,
and a budget — and the process tells you: **(1) aggregate or disaggregate, and (2) the optimal operating
point** (topology × batch × concurrency × chunk × every knob), in $/Mtok and latency.

It is a **predict → measure → re-calibrate loop**, grounded in the research (TaiChi, NetKV, Beyond-the-Buzz,
DistServe, Splitwise, the PyTorch+vLLM blog) and proven end-to-end on Nemotron-3 Ultra 550B / p5en (this repo's
`study/` + `optimize/`). You spend GPU hours only where the cheap analytical layers say the decision is close.

```
   ┌─ L0 PREDICT (no GPUs) ──────────────────────────────────────────────────────────┐
   │  analyze/calc.py     → agg/hybrid/disagg verdict + memory-fit (does it even fit?) │
   │  analyze/cost.py     → $/Mtok agg vs disagg at the SLA                            │
   │  analyze/matrix.py   → the same across models × instances × SLA tiers (breadth)   │
   │  analyze/optimizer.py→ OPTIMAL (topology,batch,conc,chunk,…) for SLA+cost + sens. │
   │  web/index.html      → all of the above, interactive, no keys                     │
   └──────────────────────────────────┬───────────────────────────────────────────────┘
            decision close, or want ground truth?  ▼
   ┌─ L1 RECOMMEND (no GPUs) ─────────────────────────────────────────────────────────┐
   │  aiconfigurator → NVIDIA profiled-silicon agg-vs-disagg winner + xPyD + TP/PP     │
   └──────────────────────────────────┬───────────────────────────────────────────────┘
            ▼
   ┌─ L2 CALIBRATE FABRIC (1 GPU run) ────────────────────────────────────────────────┐
   │  kv-bench / nixlbench → measured KV-transfer GB/s → feed back into calc.py CAL    │
   └──────────────────────────────────┬───────────────────────────────────────────────┘
            ▼
   ┌─ L3 MEASURE (live GPUs) ─────────────────────────────────────────────────────────┐
   │  study/run-study.sh   → controlled agg-vs-disagg A/B (single variable = topology) │
   │  bench/sweep.py       → batch×concurrency ramp to the goodput knee, ANY endpoint  │
   └──────────────────────────────────┬───────────────────────────────────────────────┘
            ▼  measured knee + $/Mtok
   ┌─ RE-CALIBRATE ───────────────────────────────────────────────────────────────────┐
   │  update optimizer.py CAL_OBS anchors (b_knee, itl0, tput_sat, OOM gates) → the    │
   │  calculator now predicts THIS model+hardware; re-run L0 for the rest of the space │
   └──────────────────────────────────────────────────────────────────────────────────┘
```

## How to repeat it for a NEW MODEL

1. **Add the model** to `models/top_models.yaml` with arch params from its HF `config.json` (n_layers,
   n_heads, n_kv_heads, hidden, head_dim, weight_dtype, max_ctx; for MoE add params_total_B + params_active_B;
   for MLA add `kv_compression: mla` + kv_lora_rank). The two special cases that matter: **MoE** (active vs
   total params) and **MLA** (compressed KV) — `calc.py` handles both.
2. **L0 predict:** `python3 analyze/optimizer.py --instance <inst> --isl <I> --osl <O> --slo-ttft-ms <T>
   --slo-tpot-ms <P> --objective cost` → the predicted optimal config + sensitivity. Also `calc.py` for the
   agg/disagg verdict and `cost.py` for $/Mtok. If memory-fit says "no-fit", raise TP or use a bigger-HBM
   instance before anything else.
3. **L1 (optional):** `aiconfigurator cli default --model-path <hf-id> --total-gpus N --system <h100|h200|
   b200>_sxm --backend <vllm|trtllm|sglang> --isl I --osl O --ttft T --tpot P` → recommended xPyD + per-phase
   parallelism + deployable YAML.
4. **L3 measure** (only if the decision is close or you need ground truth): deploy the agg arm + disagg arm
   (templates in `study/deploy/` + `optimize/deploy/`), then
   `python3 bench/sweep.py --endpoint <url> --model <name> --topology <agg|disagg> --concurrency 1,4,8,16,32,64,128`
   → the measured goodput knee. Run both arms; `study/run-study.sh` automates the controlled single-variable A/B.
5. **Re-calibrate:** put the measured anchors (knee concurrency, ITL floor, peak tok/s, any OOM constraint)
   into `optimizer.py` `CAL_OBS["<model>@<instance>"]`. Now the calculator predicts this model+hardware; L0
   covers the rest of the SLA/ISL/OSL space without more GPU runs.

## How to repeat it for NEW COMPUTE (different GPU / instance)

1. **Add the instance** to `analyze/calc.py` `INSTANCES{}`: `gpus`, `hbm_GBs` (bandwidth), `hbm_cap_GB`
   (capacity — drives memory-fit), `fp16_TFLOPs`, `efa_nics`, `efa_Gbps`, `nvlink_GBs`. Add its $/hr to
   `analyze/cost.py` `PRICE_PER_HR{}`.
2. The memory-fit math (weights vs aggregate HBM capacity) + roofline (HBM-BW for decode, FLOPs for prefill)
   re-derive automatically. The same calc/cost/matrix/optimizer pipeline runs unchanged.
3. **L2 fabric calibration** matters most when the interconnect changes (EFA vs NVLink vs TCP vs InfiniBand):
   measure achieved KV-transfer GB/s with `kv-bench`/`nixlbench` and update `calc.py` `CAL["kv_transfer_
   efficiency"]` / `TIERS{}`. (PyTorch+vLLM blog used TCP and found single-stream is the bottleneck; we use
   EFA multi-rail. The fabric tier is a first-class knob — NetKV.)
4. Re-measure the knee on the new hardware (L3) and re-calibrate (different HBM/BW → different b_knee).

## How to repeat it for a NEW ENGINE (vLLM / SGLang / TRT-LLM / Dynamo / hosted)

`bench/sweep.py` speaks **plain OpenAI `/v1/chat/completions` (streaming)** — point it at any endpoint, pass
`--topology agg|disagg`. The decision methodology and the goodput-knee math are identical across engines; only
the deploy manifest + the engine-specific knob NAMES change (the `docs/KNOBS.md` table maps each knob to vLLM/
Dynamo flags; for TRT-LLM/SGLang the concept is the same, the flag name differs). **Dynamo is one backend, not
the core** — the analysis (`analyze/`) and measurement (`bench/`) layers are vendor-free.

## The decision rule (what the process concludes)

**Aggregate vs disaggregate is regime-dependent, and the process measures the regime rather than assuming it:**
- **Aggregate** when: short context (ISL not ≫ OSL), cost-per-token is the objective, the model fits and
  decode isn't interference-bound. (Our 550B/p5en short-ctx result: agg 2.1× cheaper — confirmed by calc +
  live A/B + aiconfigurator, three independent methods.)
- **Disaggregate** when: long input (prefill interference high), or the objective is **per-user latency /
  tail-latency / TTFT-SLA attainment** with an independently-scaled prefill pool. (aiconfigurator: disagg
  3.3× tok/s/user + 2.9× lower request-latency at ISL8192.)
- **Hybrid** (TaiChi) in the balanced middle.

**The optimal operating point within a topology** = the **goodput knee**: the highest concurrency whose joint
(TTFT, TPOT) SLO attainment stays ≥90%. Beyond the knee, throughput is flat and latency explodes (measured:
550B knee at concurrency 32 — 292 tok/s; at 64/128 tok/s is flat but TTFT goes 2.9 s→16 s→42 s).

## Hard constraints the process surfaces (don't skip the feasibility gate)
- **Memory-fit first.** A model that barely fits has near-zero KV budget → tiny concurrency → high $/token,
  regardless of latency. `calc.py` 3-state fit (fits/tight/no-fit) gates everything.
- **CUDA-graph feasibility.** Re-enabling graphs is the biggest decode-latency lever — but on a memory-tight
  config it OOMs (MEASURED: 550B/TP8/util0.90 → engine-core init failure). The optimizer encodes this as a
  feasibility gate; graphs need TP16 or fp8 KV on tight models. **Predicted by calc.py `min_util`, confirmed live.**
- **Per-model footguns** (e.g. hybrid-Mamba: PP>1 hangs, `--block-size 128` crashes, `kv_role` mis-route) live
  in `docs/KNOBS.md` — check them before sweeping.

## Honest scope
- The L0 models are first-order, calibrated to measured anchors; they give the **direction + the where-to-
  spend-GPU**, and L3 replaces estimates with measurements. The re-calibrate loop is what makes the calculator
  trustworthy for a given model+hardware.
- Proven end-to-end on one model (550B) + one instance (p5en) + one engine (vLLM/Dynamo). The breadth across
  models/instances is analytical (`docs/MATRIX.md`); each new live cell tightens the calibration.
