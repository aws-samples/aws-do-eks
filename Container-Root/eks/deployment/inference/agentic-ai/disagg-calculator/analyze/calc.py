#!/usr/bin/env python3
"""
Author: Anton Alexander
Source: github.com/dmvevents/dynamo-disagg-optimizer · live: dmvevents.github.io/dynamo-disagg-optimizer/calculator.html

DISCLAIMER: Provided free, as a utility, for estimation and planning ONLY. AWS and the authors make no
warranty or guarantee of model performance and accept no liability for results obtained from its use.
Actual measured numbers will differ; validate on your own hardware before deployment decisions. AS IS.

calc.py — analytical "should I disaggregate?" model for ANY (instance, model, workload).

Given an AWS instance type + model characteristics + workload SLO, estimate — WITHOUT running GPUs —
whether PD disaggregation, aggregation, or hybrid is favored, plus the underlying quantities that drive
the decision (KV size per request, KV-transfer time over the fabric, prefill compute time, decode-step
time, roofline regime). Outputs a JSON the HTML page + chart renderer + visual-LLM verdict all consume.

Grounded in first-order rooflines and CALIBRATED to this org's measured Nemotron-3 Ultra 550B / p5en
numbers (see CAL/calibration below). It is an ESTIMATOR (order-of-magnitude + direction), not a simulator —
it tells you where to spend GPU hours, then the live sweep (a live GPU sweep) confirms.

Pure-Python stdlib only, so it runs headless and the HTML pages reimplement the SAME formulas in JS
(kept honest by tests/parity.py, which asserts calc.py == calculator.html == index.html on a grid).

=========================================================================================================
PHYSICS NOTES (what this models, and the four things a naive roofline gets wrong — fixed here 2026-06-15
after a deep audit; see docs/AUDIT-2026-06-15-deep-review.md):

  1. HYBRID-MAMBA KV. Attention KV scales with the number of ATTENTION layers, not all layers. A Mamba-2
     hybrid (nemotron_h: 12 attention of 108 layers) also carries a CONSTANT recurrent SSM state per
     request (mamba_num_heads*mamba_head_dim*d_state, float32) that does NOT grow with ISL. Both are
     modeled. Using full-GQA-over-all-layers (the old bug) overstates attention KV ~39x AND misses the
     ~415 MB Mamba state entirely; the two errors coincidentally cancelled near ISL=512.

  2. QUANTIZED PREFILL. Peak FLOP/s doubles for fp8 and quadruples for fp4 vs fp16 on Hopper/Blackwell
     tensor cores. Using fp16 peak for an fp8 model overstates prefill time ~2x -> overstates interference
     -> biases the verdict toward 'disaggregate'. We scale peak by a dtype multiplier.

  3. ATTENTION O(ISL^2). Prefill compute is 2*P*ISL (linear, GEMM-dominated) PLUS the quadratic attention
     term 4*ISL^2*hidden per attention layer, which dominates at long context. Both are modeled.

  4. DECODE KV READ. Per-token decode reads the weights AND the whole KV cache accumulated so far, so ITL
     grows with context. We add the KV-read term (context-dependent), on top of the calibration correction.

  Plus: chunked-prefill recovery (modern vLLM/Dynamo chunk prefill, removing most interference), an SLO
  gate (the verdict now respects TTFT/TPOT budgets), named (not magic) decision constants, and the
  calibration ledger is WIRED IN (measured ITL used when an anchor exists, with the raw roofline + the
  correction factor shown transparently).
=========================================================================================================
"""
from __future__ import annotations
import argparse, json, math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
try:
    import calibration as _calib            # wired in: measured-first ITL + transparent correction factors
except Exception:
    _calib = None

# ---- hardware catalog (AWS GPU instances) : per-GPU HBM BW + CAPACITY, FP16 dense TFLOP/s, GPUs, EFA ----
# hbm_GBs   = HBM BANDWIDTH per GPU (GB/s) — drives the decode roofline (memory-bound per-token read).
# hbm_cap_GB= HBM CAPACITY per GPU (GB)    — drives the memory-FIT math (does the model+KV fit? how much KV budget?).
# fp16_TFLOPs = DENSE fp16/bf16 tensor-core peak. fp8 ~2x, fp4 ~4x (see DTYPE_PEAK_MULT).
INSTANCES = {
    # name:           gpus, hbm_GBs(bw), hbm_cap_GB, fp16_TFLOPs, efa_nics, efa_Gbps, nvlink_GBs
    "p5.48xlarge":    {"gpu": "H100", "gpus": 8, "hbm_GBs": 3350, "hbm_cap_GB": 80,  "fp16_TFLOPs": 989,  "efa_nics": 32, "efa_Gbps": 100, "nvlink_GBs": 900},
    "p5en.48xlarge":  {"gpu": "H200", "gpus": 8, "hbm_GBs": 4800, "hbm_cap_GB": 141, "fp16_TFLOPs": 989,  "efa_nics": 16, "efa_Gbps": 200, "nvlink_GBs": 900},
    "p6-b200.48xlarge":{"gpu": "B200","gpus": 8, "hbm_GBs": 8000, "hbm_cap_GB": 180, "fp16_TFLOPs": 2250, "efa_nics": 8,  "efa_Gbps": 400, "nvlink_GBs": 1800},
    "p4d.24xlarge":   {"gpu": "A100", "gpus": 8, "hbm_GBs": 2039, "hbm_cap_GB": 40,  "fp16_TFLOPs": 312,  "efa_nics": 4,  "efa_Gbps": 100, "nvlink_GBs": 600},
}

# ---- calibration constants (measured anchors so the estimator tracks reality, not just theory) ----
# Nemotron-3 Ultra 550B on p5en, TP8/PP1, NIXL LIBFABRIC: per-transfer KV ~5.3 GB/s uncontended,
# decode ITL ~82 ms @ low concurrency. The fabric-efficiency factor folds in SRD ramp + descriptor
# granularity (a strided pull achieves ~5.3 GB/s, not the 16*25=400 GB/s line rate).
CAL = {"kv_transfer_efficiency": 0.0095,  # end-to-end KV-hop efficiency vs aggregate line rate. Calibrated to the
       # MEASURED disagg TTFT penalty: 486MB shipped in ~127.5ms = 3.81 GB/s = 0.0095×400GB/s (p5en). This is the
       # END-TO-END penalty (fabric + NIXL handshake + serialization), NOT raw fabric streaming BW — matches
       # optimizer.py disagg_ttft_penalty_ms=127 (disagg c1 TTFT 238 vs agg 110). Was 0.013 (predicted only 93ms,
       # under the measured 127ms); corrected 2026-06-17 per the research-skeptic audit.
       "mfu_prefill": 0.45,              # prefill compute MFU (compute-bound, batched)
       "mbu_decode": 0.65}               # decode HBM-bandwidth utilization roofline ceiling (memory-bound, per-token)

# ---- DECISION CONSTANTS (named, not magic — audit finding N5). These are HEURISTIC weights tuned so the
# one MEASURED anchor (550B/p5en, agg wins ~2.1x => verdict 'hybrid'/'aggregate') lands correctly. They are
# NOT derived from a paper and are calibrated to n=1; outputs are flagged accordingly until the ledger grows. ----
DECISION = {
    "interference_scale": 4.0,   # interference = 1 - exp(-imbalance/scale); larger scale => softer rise
    "toll_scale": 4.0,           # toll = 1/(1 + transfer_frac*scale); larger scale => transfer punished harder
    "threshold_disagg": 0.55,    # fav >= this => disaggregate
    "threshold_hybrid": 0.30,    # fav >= this (and < disagg) => hybrid
    # chunked-prefill removes most prefill->decode interference on modern vLLM/Dynamo. 0 = naive (prefill
    # stalls ALL co-batched decodes, the old model); 1 = perfectly chunked. 0.7 matches pd_pool_scaling.py.
    "chunked_prefill_recovery": 0.7,
}

# ---- quantization peak-FLOP multipliers (audit finding N3). Tensor-core dense peak relative to fp16/bf16. ----
DTYPE_PEAK_MULT = {"fp16": 1.0, "bf16": 1.0, "fp8": 2.0, "int8": 2.0, "fp4": 4.0}
DTYPE_BYTES = {"fp16": 2, "bf16": 2, "fp8": 1, "fp4": 0.5, "int8": 1}

# ---- NetKV (arXiv:2606.03910) network-tier placement: where prefill<->decode sit in the DC topology
# sets the EFFECTIVE KV-transfer bandwidth. The KV cache must cross this link before decode starts, so it
# enters the TTFT budget. tier downgrades (NVLink -> ToR -> spine -> cross-pod core) shrink B_eff, and
# NetKV Prop.1 shows network-oblivious placement is arbitrarily suboptimal as context (ISL) grows.
# NOTE: default 'fabric_aggregate' uses the calibrated per-transfer reality (our measured ~5.3 GB/s, which
# is itself a same-rack/tier1 regime). Pass an explicit net_tier for cross-rack/cross-pod placement studies. ----
TIERS = {
    "tier0_nvlink":    {"GBs": 450.0, "desc": "same node / NVLink (no fabric hop — effectively aggregation)"},
    "tier1_tor":       {"GBs": 12.5,  "desc": "same rack / ToR (1 EFA hop) — our measured ~5.3 GB/s/transfer regime"},
    "tier2_spine":     {"GBs": 6.25,  "desc": "cross-rack / spine (2 hops)"},
    "tier3_core":      {"GBs": 3.125, "desc": "cross-pod / core (3 hops) — NetKV's worst tier"},
    "fabric_aggregate":{"GBs": None,  "desc": "instance EFA line-rate * calibrated efficiency (default; ~tier1 same-rack)"},
}


def _n_attn_layers(model: dict) -> int:
    """Number of ATTENTION layers (the only ones with a growing KV cache). For a hybrid-Mamba model this is
    far fewer than n_layers (nemotron_h: 12 of 108). Resolution order:
      1. explicit n_attn_layers
      2. count 'attention' in layers_block_type (the HF config.json field)
      3. dense/MoE default = all layers have attention
    A hybrid-mamba family with NO attention-layer info falls back to n_layers and emits a caveat (handled
    in _caveats) — better to over-count visibly than to silently guess a split."""
    if model.get("n_attn_layers") is not None:
        return int(model["n_attn_layers"])
    lbt = model.get("layers_block_type")
    if isinstance(lbt, (list, tuple)) and lbt:
        return sum(1 for t in lbt if str(t).lower() == "attention")
    return int(model["n_layers"])


def mamba_state_bytes(model: dict) -> float:
    """Constant Mamba-2 recurrent (SSM) + conv state per REQUEST — does NOT grow with ISL. Disagg must ship
    this alongside the attention KV. nemotron_h: mamba_num_heads*mamba_head_dim*d_state float32 per mamba
    layer (~8.4 MB) * 48 layers ~= 415 MB. Zero for non-Mamba families."""
    if model.get("family") != "hybrid-mamba":
        return 0.0
    n_mamba = model.get("n_mamba_layers")
    if n_mamba is None:
        lbt = model.get("layers_block_type")
        if isinstance(lbt, (list, tuple)) and lbt:
            n_mamba = sum(1 for t in lbt if str(t).lower() in ("mamba", "mamba2"))
        else:
            n_mamba = 0
    mh = model.get("mamba_num_heads", 0)
    mhd = model.get("mamba_head_dim", 0)
    d_state = model.get("mamba_d_state", 128)
    d_conv = model.get("mamba_d_conv", 4)
    cache_db = DTYPE_BYTES.get(model.get("mamba_cache_dtype", "fp32"), 4)
    if mh and mhd and n_mamba:
        ssm = mh * mhd * d_state * cache_db
        conv = mh * mhd * max(d_conv - 1, 1) * cache_db   # causal depthwise conv caches kernel-1 timesteps
        return (ssm + conv) * n_mamba
    return 0.0


def kv_bytes_per_token(hidden, n_kv_heads, n_heads, n_layers, head_dim, kv_dtype, model=None) -> float:
    """ATTENTION KV cache bytes per token (the part that GROWS with context). GQA-aware:
    2 (K,V) * n_kv_heads * head_dim * n_ATTENTION_layers * dtype_bytes.

    Branches:
      - MLA (DeepSeek-V3): cache is the COMPRESSED latent, (kv_lora_rank + qk_rope_head_dim) per token per
        layer — NOT full K/V heads. Naive GQA on MLA overstates KV ~10x.
      - hybrid-Mamba: only the ATTENTION layers hold a growing KV cache (the Mamba layers carry a constant
        recurrent state handled by mamba_state_bytes()). Using n_layers here was the old bug (overstated ~39x).
    """
    model = model or {}
    if model.get("kv_compression") == "mla":
        lora = model.get("kv_lora_rank", 512)
        rope = model.get("qk_rope_head_dim", 64)
        return (lora + rope) * n_layers * DTYPE_BYTES.get(kv_dtype, 2)
    if head_dim is None:
        head_dim = hidden / max(n_heads, 1)
    attn_layers = _n_attn_layers(model) if model else n_layers
    return 2 * n_kv_heads * head_dim * attn_layers * DTYPE_BYTES.get(kv_dtype, 2)


def _params(model: dict) -> tuple[float, float]:
    """Return (params_compute_B, params_mem_B). For MoE these DIFFER: compute rooflines (prefill FLOPs,
    decode HBM-read) scale with ACTIVE params/token; memory FIT scales with TOTAL resident params.
    Backward-compat: a plain params_B (or dense model) sets both equal."""
    total = model.get("params_total_B", model.get("params_B"))
    active = model.get("params_active_B", model.get("params_B", total))
    if total is None:
        total = active
    if active is None:
        active = total
    return float(active), float(total)


def _itl_calibrated(decode_step_ms_roofline: float, model: dict) -> dict:
    """Wire in the calibration ledger (audit finding N1). Returns the roofline floor, the measured-anchor
    correction factor for this family, and the corrected ITL actually used downstream. Fully transparent:
    the caller surfaces all three so nobody can claim the displayed ITL is a raw roofline OR a pasted anchor."""
    fam = model.get("family", "dense")
    factor, n, conf = 1.0, 0, "none (raw roofline — no measured anchor for this family)"
    if _calib is not None:
        try:
            cf = _calib.correction_factor(fam, "itl_ms")
            factor, n, conf = cf.get("factor", 1.0), cf.get("n", 0), cf.get("confidence", "")
        except Exception:
            pass
    corrected = decode_step_ms_roofline * factor
    return {"roofline_ms": round(decode_step_ms_roofline, 3), "correction_factor": factor,
            "calibration_n": n, "calibration_confidence": conf, "used_ms": round(corrected, 3)}


def analyze(inst: dict, model: dict, wl: dict) -> dict:
    g = inst
    tp = model.get("tp", g["gpus"])
    pp = model.get("pp", 1)                  # pipeline-parallel stages: PP shards LAYERS → full weights spread over tp*pp GPUs
    gpus_in_group = tp * pp                   # GPUs in one serving group (one replica). PP1 => == tp (back-compat).
    params_active_B, params_total_B = _params(model)
    params_B = params_active_B              # compute rooflines use ACTIVE params (MoE-correct; ==total for dense)
    w_dtype = model.get("weight_dtype", "bf16")
    kv_dtype = model.get("kv_dtype", w_dtype)

    isl, osl = wl["isl"], wl["osl"]
    n_attn = _n_attn_layers(model)

    # --- KV size per request: ATTENTION KV (grows with ISL) + constant Mamba SSM state (if hybrid-mamba) ---
    kv_bpt = kv_bytes_per_token(model["hidden"], model["n_kv_heads"], model["n_heads"],
                                model["n_layers"], model.get("head_dim"), kv_dtype, model)
    attn_kv_bytes = kv_bpt * isl
    mamba_bytes = mamba_state_bytes(model)
    kv_bytes_req = attn_kv_bytes + mamba_bytes       # total bytes disagg must ship prefill->decode
    kv_MB = kv_bytes_req / 1e6

    # --- KV transfer time over the fabric (disagg cost) ---
    # NetKV: the prefill<->decode network TIER sets B_eff. Default = instance EFA line-rate * calibrated
    # efficiency (our measured per-transfer reality); if a tier is named, use its bandwidth instead.
    line_GBs = g["efa_nics"] * g["efa_Gbps"] / 8.0      # aggregate fabric GB/s
    tier = wl.get("net_tier", "fabric_aggregate")
    tier_GBs = TIERS.get(tier, {}).get("GBs")
    if tier_GBs:
        achieved_GBs = tier_GBs                          # NetKV tier-pinned effective bandwidth
    else:
        achieved_GBs = max(line_GBs * CAL["kv_transfer_efficiency"], 1.0)  # calibrated per-transfer reality
    kv_transfer_ms = (kv_bytes_req / 1e9) / achieved_GBs * 1000.0

    # --- prefill compute time (compute-bound): linear GEMM term + quadratic attention term ---
    # linear: 2 * P_active * ISL FLOPs (the dense matmuls). quadratic: 4 * ISL^2 * hidden per ATTENTION layer
    # (QK^T + attn*V), which dominates at long context. Mamba layers have NO quadratic term (linear in seq).
    flops_prefill_linear = 2 * params_B * 1e9 * isl
    flops_prefill_attn = 4.0 * (isl ** 2) * model["hidden"] * n_attn
    flops_prefill = flops_prefill_linear + flops_prefill_attn
    # peak FLOP/s is set by the MATMUL (compute) dtype, not the storage dtype. Default compute_dtype = weight
    # dtype (true for native W8A8 fp8 like DeepSeek-V3), but a weight-only-quant model (W8A16/AWQ) computes in
    # bf16 — set compute_dtype explicitly there so we don't over-credit the tensor-core peak.
    # ARCH GATE (LIVE-CORRECTED 2026-06-19): the dtype peak multiplier only applies if the GPU has the NATIVE
    # tensor-core instruction. fp4's 4x is BLACKWELL-only (native FP4 GEMM). On Hopper/Ampere an NVFP4 ckpt
    # runs via Marlin W4A16 (4-bit weights, in-kernel DEQUANT to bf16, compute ≈ bf16) → effective peak ~1x,
    # NOT 4x. (Live-proven: 550B-NVFP4 serves on H200 via Marlin at ~bf16 compute — results/nvfp4-probe/.)
    # fp8 is native sm89+ (Hopper/Blackwell) so keeps 2x there; on A100 (sm80) it also degrades to ~1x.
    compute_dtype = model.get("compute_dtype", w_dtype)
    gpu = g.get("gpu", "")
    _is_blackwell = gpu in ("B200", "B100", "GB200")
    _is_hopper_plus = _is_blackwell or gpu in ("H100", "H200")          # sm89+ has native fp8
    raw_mult = DTYPE_PEAK_MULT.get(compute_dtype, 1.0)
    if compute_dtype == "fp4" and not _is_blackwell:
        dtype_peak_mult = 1.0      # Marlin W4A16 dequant path on non-Blackwell: compute ≈ bf16
    elif compute_dtype in ("fp8", "int8") and not _is_hopper_plus:
        dtype_peak_mult = 1.0      # no native fp8 tensor cores pre-Hopper
    else:
        dtype_peak_mult = raw_mult                                     # native path: fp8 2x (Hopper+), fp4 4x (Blackwell)
    compute_GFLOPs = g["fp16_TFLOPs"] * dtype_peak_mult * 1e3 * tp * CAL["mfu_prefill"]
    prefill_ms = flops_prefill / (compute_GFLOPs * 1e9) * 1000.0

    # --- decode per-token time (memory-bound): read ACTIVE weights + KV-cache-so-far from HBM each step ---
    # roofline floor reads weights only; the real per-token read also includes the KV accumulated so far
    # (grows with context). Average over the decode phase => KV at ~ isl + osl/2 tokens.
    param_bytes = params_B * 1e9 * DTYPE_BYTES.get(w_dtype, 2)
    avg_ctx_tokens = isl + osl / 2.0
    kv_read_bytes = kv_bpt * avg_ctx_tokens                       # attention KV re-read each decode step (avg)
    hbm_GBs = g["hbm_GBs"] * tp * CAL["mbu_decode"]
    decode_step_ms_roofline = ((param_bytes + kv_read_bytes) / 1e9) / hbm_GBs * 1000.0
    # wire in calibration: measured-anchor correction (e.g. hybrid-mamba ~18.6x for eager+conc-1) applied,
    # with the raw roofline + factor kept visible.
    itl_cal = _itl_calibrated(decode_step_ms_roofline, model)
    decode_step_ms = itl_cal["used_ms"]

    # --- MEMORY FIT: TOTAL resident weights vs aggregate HBM CAPACITY across the tp*pp GPUs of the serving
    # group. Leftover after weights = KV budget = concurrency ceiling. Three states (no-fit / tight / fits).
    # Also reports whether CUDA graphs are feasible (audit N10): a 'tight' fit needs enforce-eager; graphs
    # need util <= 0.92. PP spans the model's LAYERS across pp nodes, so a role that doesn't fit one node
    # (550B BF16 on 1 p5en = weights eat 97.5% of HBM) gets real KV headroom + CUDA graphs at pp>=2. ---
    UTIL_CEILING = 0.98                                            # absolute safe gpu-memory-utilization ceiling
    GRAPH_UTIL_CEILING = 0.92                                      # above this, CUDA-graph capture OOMs (matches feasibility.py)
    w_bytes_per_param = DTYPE_BYTES.get(w_dtype, 2)
    weights_GB = params_total_B * w_bytes_per_param                # e.g. 550B bf16 = 1100 GB (TOTAL; PP spreads, doesn't shrink)
    hbm_cap_GB = g.get("hbm_cap_GB", 80)
    total_hbm_GB = gpus_in_group * hbm_cap_GB                      # aggregate capacity across the tp*pp GPUs in the group
    min_util_for_weights = weights_GB / max(total_hbm_GB, 1e-9)    # gpu-util just to hold the weights
    kv_budget_GB = total_hbm_GB * UTIL_CEILING - weights_GB        # KV headroom at the max safe util
    fits = kv_budget_GB > 0.5
    tight = fits and min_util_for_weights > 0.90
    fit_status = "no-fit" if not fits else ("tight" if tight else "fits")
    graph_feasible = fits and (min_util_for_weights <= GRAPH_UTIL_CEILING)
    min_gpus_to_fit = int(math.ceil(weights_GB / max(hbm_cap_GB * 0.85, 1e-9)))
    # per-request KV footprint (attention KV grows to full context + the constant Mamba state)
    kv_bytes_full_ctx = kv_bpt * (isl + osl) + mamba_bytes
    max_kv_tokens = (kv_budget_GB * 1e9 / kv_bpt) if (fits and kv_bpt > 0) else 0.0
    # concurrency = how many of THIS workload's requests fit in the KV budget. KV grows during decode, so
    # average footprint ~ isl + osl/2 (audit N11). Mamba state is per-request constant overhead.
    per_req_avg_bytes = kv_bpt * (isl + osl / 2.0) + mamba_bytes
    concurrency_at_isl = (kv_budget_GB * 1e9 / per_req_avg_bytes) if (fits and per_req_avg_bytes > 0) else 0.0
    per_req_maxctx_bytes = kv_bpt * model.get("max_ctx", isl + osl) + mamba_bytes
    concurrency_at_maxctx = (kv_budget_GB * 1e9 / per_req_maxctx_bytes) if (fits and per_req_maxctx_bytes > 0) else 0.0

    # --- the decision (TaiChi premise): aggregation makes one prefill burst STALL the decode stream of every
    # co-batched request (TPOT interference); disaggregation removes that interference but pays a KV-transfer
    # toll. Disagg wins when interference-removed >> transfer-toll-added. Chunked prefill (modern engines)
    # reclaims most of the interference, so we discount it by chunked_prefill_recovery. ---
    decode_phase_ms = decode_step_ms * osl
    # (a) transfer toll: KV-transfer time as a fraction of the decode phase it unblocks. cheap => good for disagg.
    transfer_overhead_frac = kv_transfer_ms / max(decode_phase_ms, 1e-6)
    # (b) interference removed: a prefill burst (prefill_ms) blocks ~prefill_ms/decode_step decode steps of
    #     other requests. Normalize against one decode step => "how many ITLs a prefill stalls". Chunked
    #     prefill interleaves prefill chunks with decode, recovering `chunked_prefill_recovery` of it.
    prefill_decode_imbalance = prefill_ms / max(decode_step_ms, 1e-6)
    cpr = wl.get("chunked_prefill_recovery", DECISION["chunked_prefill_recovery"])
    interference_raw = 1.0 - math.exp(-prefill_decode_imbalance / DECISION["interference_scale"])
    interference = interference_raw * (1.0 - cpr)
    toll = 1.0 / (1.0 + transfer_overhead_frac * DECISION["toll_scale"])
    fav = toll * interference

    # chunked-prefill caps interference at (1-cpr), so favorability lives on a [0, 1-cpr] axis. Rescale the
    # thresholds onto that same axis so the verdict SHAPE is preserved (disagg stays reachable for genuinely
    # prefill-heavy, cheap-transfer workloads) instead of becoming structurally impossible at cpr>0.45.
    thr_disagg = DECISION["threshold_disagg"] * (1.0 - cpr)
    thr_hybrid = DECISION["threshold_hybrid"] * (1.0 - cpr)
    if fav >= thr_disagg:
        verdict, why = "disaggregate", "cheap KV transfer; prefill bursts would stall many decode steps under aggregation (high TPOT-interference, even after chunked-prefill)"
    elif fav >= thr_hybrid:
        verdict, why = "hybrid", "non-trivial interference but transfer/imbalance moderate — TaiChi hybrid (differentiated P/D instances) likely best"
    else:
        verdict, why = "aggregate", "prefill is cheap relative to decode (low interference, incl. chunked-prefill) and/or KV transfer toll high — colocate"

    # --- SLO gate (audit finding N2): the verdict above is latency-physics-only. Now respect the user's SLO.
    # If shipping the KV would blow the TTFT budget, disagg is not viable regardless of favorability. If even
    # the predicted single-stream ITL exceeds the TPOT budget, flag it (no topology fixes a too-slow model). ---
    slo_ttft_ms = wl.get("slo_ttft_ms")
    slo_tpot_ms = wl.get("slo_tpot_ms")
    slo_notes = []
    slo_viable_disagg = True
    if slo_ttft_ms is not None:
        # disagg's TTFT critical path = prefill + the KV hop. It's viable only if that sum fits the budget.
        # (Was a 0.5*TTFT heuristic — refuted 2026-06-17: the physically-correct gate is the additive one,
        # which spuriously-rejected disagg whenever transfer was 50-100% of budget even if prefill was tiny.)
        if prefill_ms + kv_transfer_ms > slo_ttft_ms:
            slo_viable_disagg = False
            slo_notes.append(f"prefill+transfer {prefill_ms + kv_transfer_ms:.0f}ms exceeds TTFT budget {slo_ttft_ms:.0f}ms — disagg can't meet the TTFT SLO")
    if slo_tpot_ms is not None and decode_step_ms > slo_tpot_ms:
        slo_notes.append(f"predicted ITL {decode_step_ms:.0f}ms exceeds TPOT budget {slo_tpot_ms:.0f}ms (model/hardware too slow at this op-point)")
    verdict_pre_slo = verdict
    if verdict == "disaggregate" and not slo_viable_disagg:
        verdict, why = "aggregate", "favorability prefers disagg, but KV transfer would breach the TTFT SLO — colocate (no transfer hop)"

    # --- HELP / NO-OP / REGRESS vs aggregation (the operational question) ----------------------------------
    # The agg/hybrid/disagg verdict above says WHICH topology; this says, per axis, whether moving from plain
    # aggregation to disaggregation HELPS, does nothing, or REGRESSES — and by how much. Each axis is a
    # speedup ratio = (aggregation value) / (disaggregation value), oriented so >1 = disagg is BETTER, <1 =
    # disagg is WORSE (a regression). A ±DISAGG_BAND dead-band around 1.0 = NO-OP (within modeling noise).
    # Grounded in the same quantities the verdict uses; the COST axis reproduces the MEASURED 550B regression
    # (decode-dominated short chat → tiny interference → disagg pays ~2x GPUs for ~nothing → ~0.5x = regress
    # ~2x, matching the measured agg-wins-2.1x anchor) and flips to >1 for prefill-heavy agent/RAG workloads.
    DISAGG_BAND = 0.10                                          # ±10% around parity = NO-OP (within n=1 noise)

    def _band(sp):
        if sp >= 1.0 + DISAGG_BAND: return "helps"
        if sp <= 1.0 - DISAGG_BAND: return "regresses"
        return "no-op"

    # (1) ITL / per-token decode latency: aggregation inflates the decode stream by the prefill interference
    #     it couldn't hide; disagg removes it. agg_ITL = ITL*(1+interference), disagg_ITL = ITL. >1 => disagg better.
    itl_speedup = 1.0 + interference
    # (2) TTFT: disagg ADDS the KV hop to the first-token critical path (prefill+transfer) vs agg's prefill
    #     alone. <1 here = disagg is WORSE on TTFT (the long-KV-ship regression the SLO gate also guards).
    ttft_speedup = prefill_ms / max(prefill_ms + kv_transfer_ms, 1e-9)
    # (3) COST $/Mtok at the 1P:1D floor: disagg lifts decode goodput by the interference 'uplift' (cost.py)
    #     but spends 2x the GPUs. ratio = uplift/2 (price-independent — the $/hr cancels). uplift matches
    #     cost.py: 1/(1-0.5*interference). <1 => disagg costs MORE per token (the 2x-GPU regression).
    cost_uplift = 1.0 / max(1.0 - 0.5 * interference, 0.3)
    cost_speedup = cost_uplift / 2.0
    axes = {
        "cost_per_token": {"speedup_disagg_over_agg": round(cost_speedup, 3), "band": _band(cost_speedup),
                           "basis": "1P:1D floor: decode goodput uplift 1/(1-0.5*interf) vs 2x GPUs (price-independent ratio = uplift/2)"},
        "ttft":           {"speedup_disagg_over_agg": round(ttft_speedup, 3), "band": _band(ttft_speedup),
                           "basis": "agg prefill-only vs disagg prefill+KV-hop on the first-token critical path"},
        "itl":            {"speedup_disagg_over_agg": round(itl_speedup, 3), "band": _band(itl_speedup),
                           "basis": "agg decode inflated by (1+interference) co-batch stall; disagg removes it"},
    }
    # overall: REGRESSES if any axis regresses and none helps enough to offset; HELPS if >=1 axis helps and
    # none regresses; else MIXED/NO-OP. Cost is the tie-breaker (the decision most teams act on).
    bands = [a["band"] for a in axes.values()]
    if "regresses" in bands and "helps" not in bands:
        disagg_overall = "regresses"
        disagg_summary = "disaggregation REGRESSES here vs aggregation — " + ", ".join(
            f"{k} {v['speedup_disagg_over_agg']}x" for k, v in axes.items())
    elif "helps" in bands and "regresses" not in bands:
        disagg_overall = "helps"
        disagg_summary = "disaggregation HELPS here vs aggregation — " + ", ".join(
            f"{k} {v['speedup_disagg_over_agg']}x" for k, v in axes.items())
    elif "helps" in bands and "regresses" in bands:
        disagg_overall = "mixed"
        disagg_summary = ("MIXED: disagg helps on " + "/".join(k for k, v in axes.items() if v["band"] == "helps")
                          + " but regresses on " + "/".join(k for k, v in axes.items() if v["band"] == "regresses")
                          + " — pick on your priority axis (cost vs latency)")
    else:
        disagg_overall = "no-op"
        disagg_summary = "disaggregation is roughly a NO-OP here (within ±%d%% of aggregation on every axis) — the split's cost ≈ its benefit; stay aggregated for simplicity" % int(DISAGG_BAND * 100)

    out = {
        "instance": {"name": wl.get("instance_name"), **g, "line_rate_GBs": round(line_GBs, 1)},
        "model": {**{k: model[k] for k in ("name", "n_layers", "n_heads", "n_kv_heads", "hidden", "family") if k in model},
                  "n_attn_layers": n_attn, "params_active_B": params_active_B, "params_total_B": params_total_B},
        "workload": {"isl": isl, "osl": osl, "tp": tp, "pp": pp, "gpus_in_group": gpus_in_group,
                     "weight_dtype": w_dtype, "kv_dtype": kv_dtype, "chunked_prefill_recovery": cpr},
        "kv": {"attn_bytes_per_token": round(kv_bpt, 1), "attn_MB_per_request": round(attn_kv_bytes / 1e6, 2),
               "mamba_state_MB": round(mamba_bytes / 1e6, 1), "MB_per_request": round(kv_MB, 1)},
        "memory_fit": {
            "weights_GB": round(weights_GB, 1), "total_hbm_GB": round(total_hbm_GB, 1),
            "kv_budget_GB": round(kv_budget_GB, 1), "fits_at_tp": fits, "fit_status": fit_status,
            "graph_feasible": graph_feasible, "graph_util_ceiling": GRAPH_UTIL_CEILING,
            "min_util_for_weights": round(min_util_for_weights, 3),
            "min_gpus_to_fit": min_gpus_to_fit, "gpus_in_play": gpus_in_group,
            "max_kv_tokens": int(max_kv_tokens),
            "concurrency_at_workload": round(concurrency_at_isl, 1),
            "concurrency_at_maxctx": round(concurrency_at_maxctx, 1),
            "note": ("does NOT fit on %d GPUs (weights %.0fGB > %.0fGB safe HBM) — need >=%d GPUs: span nodes (pp>=2) / quantize (fp8)"
                     % (gpus_in_group, weights_GB, total_hbm_GB * UTIL_CEILING, min_gpus_to_fit) if not fits else
                     ("TIGHT: weights eat %.0f%% of HBM on %d GPUs — needs gpu-util>=%.2f + enforce-eager (NO CUDA graphs); "
                      "span nodes (pp>=2, e.g. tp%d/pp2=%d GPUs) or fp8 to unlock KV headroom + graphs; "
                      "~%d KV tokens => ~%.0f concurrent reqs at ctx=%d"
                      % (min_util_for_weights * 100, gpus_in_group, max(min_util_for_weights + 0.01, 0.95),
                         tp, tp * 2, int(max_kv_tokens), concurrency_at_isl, isl + osl)) if tight else
                     "fits (CUDA graphs OK); ~%d KV tokens => ~%.0f concurrent reqs at ISL+OSL=%d"
                     % (int(max_kv_tokens), concurrency_at_isl, isl + osl)),
        },
        "timings_ms": {
            "kv_transfer": round(kv_transfer_ms, 2),
            "prefill_compute": round(prefill_ms, 1),
            "prefill_attn_quadratic_frac": round(flops_prefill_attn / max(flops_prefill, 1e-9), 3),
            "decode_step_ITL": round(decode_step_ms, 2),
            "decode_step_ITL_roofline": itl_cal["roofline_ms"],
            "decode_phase_total": round(decode_phase_ms, 1),
        },
        "calibration": {
            "itl_correction_factor": itl_cal["correction_factor"], "n": itl_cal["calibration_n"],
            "confidence": itl_cal["calibration_confidence"],
            "note": ("decode ITL = roofline %.2fms x measured correction %.2fx = %.1fms (family '%s')"
                     % (itl_cal["roofline_ms"], itl_cal["correction_factor"], decode_step_ms, model.get("family", "dense"))
                     if itl_cal["calibration_n"] else
                     "decode ITL = raw roofline %.2fms (no measured anchor for family '%s' — directional only)"
                     % (itl_cal["roofline_ms"], model.get("family", "dense"))),
        },
        "fabric": {"achieved_GBs_per_transfer": round(achieved_GBs, 2), "efficiency": CAL["kv_transfer_efficiency"],
                   "net_tier": tier, "net_tier_desc": TIERS.get(tier, {}).get("desc", "")},
        "decision": {
            "verdict": verdict, "favorability": round(fav, 3), "why": why,
            "verdict_pre_slo": verdict_pre_slo,
            "transfer_overhead_frac": round(transfer_overhead_frac, 4),
            "prefill_decode_imbalance": round(prefill_decode_imbalance, 1),
            "interference": round(interference, 3), "interference_raw": round(interference_raw, 3),
            "chunked_prefill_recovery": cpr,
            "transfer_toll": round(toll, 3),
            "thresholds": {"disagg": round(thr_disagg, 3), "hybrid": round(thr_hybrid, 3),
                           "base_disagg": DECISION["threshold_disagg"], "base_hybrid": DECISION["threshold_hybrid"],
                           "rescaled_by": round(1.0 - cpr, 3),
                           "note": "thresholds rescaled by (1-chunked_prefill_recovery) to match the capped interference axis"},
            "slo": {"ttft_ms": slo_ttft_ms, "tpot_ms": slo_tpot_ms, "disagg_slo_viable": slo_viable_disagg,
                    "notes": slo_notes},
        },
        "disagg_vs_agg": {
            "overall": disagg_overall, "summary": disagg_summary, "band_pct": int(DISAGG_BAND * 100),
            "axes": axes,
            "note": "speedup = aggregation/disaggregation per axis; >1 = disagg better, <1 = disagg REGRESSES, "
                    "within ±%d%% = no-op. Cost axis is the price-independent 1P:1D-floor ratio." % int(DISAGG_BAND * 100),
        },
        "caveats": _caveats(model, itl_cal),
    }
    return out


def _caveats(model: dict, itl_cal: dict | None = None) -> list[str]:
    out = []
    fam = model.get("family", "dense")
    if fam == "hybrid-mamba":
        # if we couldn't resolve an attention/mamba split, say so loudly (we fell back to all-layers)
        if model.get("n_attn_layers") is None and not model.get("layers_block_type"):
            out.append("hybrid-Mamba but NO attention/mamba layer split provided (n_attn_layers/layers_block_type) "
                       "— KV computed over ALL layers (OVER-counts attention KV; add the split for accuracy).")
        out.append("hybrid-Mamba: attention KV scales with the few attention layers; a CONSTANT Mamba SSM state "
                   "(~hundreds of MB, ISL-independent) is shipped too. PP1 only on EFA (PP2 = open vLLM bug); "
                   "KV pull descriptor-bound (~5.3 GB/s/transfer measured).")
    if fam == "moe":
        out.append("MoE: KV is standard attention (per-active-params), but expert-parallel comms add a separate axis not modeled here.")
    if fam == "moe-mla":
        out.append("MoE+MLA: KV is the compressed latent (kv_lora_rank+rope), far smaller than naive GQA; EP comms not modeled.")
    if itl_cal is not None:
        if itl_cal.get("calibration_n", 0) >= 1:
            out.append("decode ITL is calibrated to a MEASURED anchor (n=%d, %s); raw roofline shown alongside. "
                       "Single-point calibration — re-confirm off the bf16/H200/TP8 anchor with a live GPU sweep."
                       % (itl_cal["calibration_n"], itl_cal.get("calibration_confidence", "")))
        else:
            out.append("decode ITL is the RAW HBM roofline (no measured anchor for this family) — likely OPTIMISTIC "
                       "for eager-mode / low-concurrency; treat as a lower bound on latency.")
    out.append("Estimator only: directionally accurate, calibrated to 550B/p5en (n=1). Confirm the verdict with a live GPU sweep on real GPUs.")
    return out


def _selftest() -> int:
    # ---- Nemotron-3 Ultra 550B on p5en — REAL nemotron_h arch (from config.json) ----
    inst = INSTANCES["p5en.48xlarge"]
    model = {"name": "nemotron-ultra-550b", "family": "hybrid-mamba", "params_total_B": 550, "params_active_B": 55,
             "n_layers": 108, "n_attn_layers": 12, "n_mamba_layers": 48, "n_heads": 64, "n_kv_heads": 2,
             "hidden": 8192, "head_dim": 128, "weight_dtype": "bf16", "tp": 8, "max_ctx": 262144,
             "mamba_num_heads": 256, "mamba_head_dim": 64, "mamba_d_state": 128, "mamba_d_conv": 4,
             "mamba_cache_dtype": "fp32"}
    wl = {"isl": 512, "osl": 128, "instance_name": "p5en.48xlarge"}
    r = analyze(inst, model, wl)
    assert r["decision"]["verdict"] in ("disaggregate", "hybrid", "aggregate"), r["decision"]
    assert r["kv"]["MB_per_request"] > 0 and r["timings_ms"]["decode_step_ITL"] > 0
    # hybrid-mamba KV: attention KV must be SMALL (12 layers, 2 kv heads) and the Mamba state must DOMINATE.
    assert r["kv"]["mamba_state_MB"] > 300, r["kv"]            # ~415 MB constant SSM state
    assert r["kv"]["attn_MB_per_request"] < 20, r["kv"]       # 12 attn layers * 2 kvheads @ ISL512 ~= 6 MB
    # total KV should land in the ballpark of the MEASURED 486 MB/req anchor (not the old buggy 247)
    assert 380 <= r["kv"]["MB_per_request"] <= 520, r["kv"]["MB_per_request"]
    # calibration WIRED IN: decode ITL must be the measured-corrected value (~82ms), not the 4.4ms roofline
    assert r["timings_ms"]["decode_step_ITL"] > 50, r["timings_ms"]
    assert r["timings_ms"]["decode_step_ITL_roofline"] < 20, r["timings_ms"]
    assert r["calibration"]["itl_correction_factor"] > 5, r["calibration"]
    # memory-fit: 550B bf16 = 1100GB; tp8 p5en = 1128GB -> tight, graphs NOT feasible
    mf = r["memory_fit"]
    assert mf["weights_GB"] == 1100.0, mf
    assert mf["fit_status"] == "tight" and mf["graph_feasible"] is False, mf
    print(f"calc.py selftest PASS — 550B/p5en verdict={r['decision']['verdict']} fav={r['decision']['favorability']} "
          f"KV={r['kv']['MB_per_request']}MB (attn {r['kv']['attn_MB_per_request']} + mamba {r['kv']['mamba_state_MB']}) "
          f"ITL={r['timings_ms']['decode_step_ITL']}ms (roofline {r['timings_ms']['decode_step_ITL_roofline']} x{r['calibration']['itl_correction_factor']}) "
          f"fit={mf['fit_status']} graphs={mf['graph_feasible']}")

    # ---- PP-aware fit (Alex's multinode-per-role, 2026-06-18): TP8/PP2 = 16 GPUs across 2 nodes spreads the
    # model's LAYERS, so the same 1100GB weights now sit in 2256GB aggregate HBM -> KV headroom + CUDA graphs. ----
    r_pp2 = analyze(inst, dict(model, pp=2), {"isl": 8192, "osl": 512, "instance_name": "p5en.48xlarge"})
    mf2 = r_pp2["memory_fit"]
    assert mf2["total_hbm_GB"] == 2256.0, mf2                       # 16 * 141 (was 1128 at pp1)
    assert mf2["weights_GB"] == 1100.0, mf2                         # TOTAL weights unchanged — PP spreads, doesn't shrink
    assert mf2["gpus_in_play"] == 16, mf2
    assert mf2["fit_status"] == "fits" and mf2["graph_feasible"] is True, mf2   # tight->fits, eager->graphs
    assert mf2["concurrency_at_workload"] > 100, mf2               # ~2150 vs ~1 at pp1 — real headroom
    # PP1 back-compat: the tight anchor must STILL hold with explicit pp=1
    assert analyze(inst, dict(model, pp=1), wl)["memory_fit"]["fit_status"] == "tight", "pp1 back-compat broke"
    print(f"calc.py selftest PASS — PP-aware fit: 550B tp8/pp2 (16 GPUs, 2 nodes) total_hbm "
          f"{mf['total_hbm_GB']:.0f}->{mf2['total_hbm_GB']:.0f}GB, fit {mf['fit_status']}->{mf2['fit_status']}, "
          f"graphs {mf['graph_feasible']}->{mf2['graph_feasible']}, conc {mf['concurrency_at_workload']:.0f}->{mf2['concurrency_at_workload']:.0f}")

    # ---- fp8 peak multiplier (N3): an fp8 model must get ~2x prefill compute vs the same model labeled bf16 ----
    m_bf16 = {"name": "x", "family": "dense", "params_total_B": 70, "params_active_B": 70, "n_layers": 80,
              "n_heads": 64, "n_kv_heads": 8, "hidden": 8192, "head_dim": 128, "weight_dtype": "bf16", "tp": 8}
    m_fp8 = {**m_bf16, "weight_dtype": "fp8"}
    p_bf16 = analyze(inst, m_bf16, {"isl": 4096, "osl": 128, "instance_name": "p5en.48xlarge"})["timings_ms"]["prefill_compute"]
    p_fp8 = analyze(inst, m_fp8, {"isl": 4096, "osl": 128, "instance_name": "p5en.48xlarge"})["timings_ms"]["prefill_compute"]
    assert abs(p_bf16 / p_fp8 - 2.0) < 0.05, (p_bf16, p_fp8)   # fp8 peak 2x => half the prefill time
    print(f"calc.py selftest PASS — fp8 peak: prefill bf16={p_bf16}ms vs fp8={p_fp8}ms (~2x, dtype peak applied)")

    # ---- ARCH GATE for fp4 (LIVE-CORRECTED 2026-06-19): fp4's 4x peak is BLACKWELL-only. On Hopper (H200) an
    # NVFP4 ckpt runs Marlin W4A16 (dequant→bf16 compute) so prefill ≈ bf16 (NOT 4x faster). On B200 it gets 4x. ----
    m_fp4 = {**m_bf16, "weight_dtype": "fp4"}
    p_fp4_h200 = analyze(INSTANCES["p5en.48xlarge"], m_fp4, {"isl": 4096, "osl": 128, "instance_name": "p5en.48xlarge"})["timings_ms"]["prefill_compute"]
    p_bf16_h200 = analyze(INSTANCES["p5en.48xlarge"], m_bf16, {"isl": 4096, "osl": 128, "instance_name": "p5en.48xlarge"})["timings_ms"]["prefill_compute"]
    assert abs(p_fp4_h200 / p_bf16_h200 - 1.0) < 0.05, ("fp4 on H200 must be ~bf16 (Marlin W4A16), NOT 4x", p_fp4_h200, p_bf16_h200)
    p_fp4_b200 = analyze(INSTANCES["p6-b200.48xlarge"], m_fp4, {"isl": 4096, "osl": 128, "instance_name": "p6-b200.48xlarge"})["timings_ms"]["prefill_compute"]
    p_bf16_b200 = analyze(INSTANCES["p6-b200.48xlarge"], m_bf16, {"isl": 4096, "osl": 128, "instance_name": "p6-b200.48xlarge"})["timings_ms"]["prefill_compute"]
    assert abs(p_bf16_b200 / p_fp4_b200 - 4.0) < 0.1, ("fp4 on B200 must be ~4x bf16 (native FP4)", p_fp4_b200, p_bf16_b200)
    print(f"calc.py selftest PASS — fp4 ARCH GATE: H200 fp4/bf16={p_fp4_h200/p_bf16_h200:.2f} (~1x Marlin, live-correct) | "
          f"B200 bf16/fp4={p_bf16_b200/p_fp4_b200:.2f} (~4x native FP4)")

    # ---- attention O(ISL^2) term (N7): quadratic fraction must RISE with ISL for a dense attention model ----
    q_short = analyze(inst, m_bf16, {"isl": 512, "osl": 128, "instance_name": "p5en.48xlarge"})["timings_ms"]["prefill_attn_quadratic_frac"]
    q_long = analyze(inst, m_bf16, {"isl": 16384, "osl": 128, "instance_name": "p5en.48xlarge"})["timings_ms"]["prefill_attn_quadratic_frac"]
    assert q_long > q_short, (q_short, q_long)
    print(f"calc.py selftest PASS — attn O(ISL^2): quadratic frac {q_short} @512 -> {q_long} @16384 (rises, as physics requires)")

    # ---- SLO gate (N2): a disagg-favored case with a tiny TTFT budget must be overridden to aggregate ----
    # craft a moderate-ISL, small-KV (few kv-heads), fast-decode case that favors disagg, then choke TTFT.
    sm = {"name": "s", "family": "dense", "params_total_B": 8, "params_active_B": 8, "n_layers": 32, "n_heads": 32,
          "n_kv_heads": 8, "hidden": 4096, "head_dim": 128, "weight_dtype": "bf16", "tp": 1}
    base = analyze(INSTANCES["p5.48xlarge"], sm, {"isl": 4096, "osl": 128, "instance_name": "p5.48xlarge"})
    assert base["decision"]["verdict"] == "disaggregate", ("SLO-gate base must be disagg", base["decision"])
    choked = analyze(INSTANCES["p5.48xlarge"], sm, {"isl": 4096, "osl": 128, "instance_name": "p5.48xlarge",
                                                    "slo_ttft_ms": 5.0})  # absurdly tight TTFT
    assert choked["decision"]["verdict"] == "aggregate" and choked["decision"]["slo"]["disagg_slo_viable"] is False, choked["decision"]
    print(f"calc.py selftest PASS — SLO gate: disagg→aggregate when TTFT budget breached "
          f"(pre-SLO {choked['decision']['verdict_pre_slo']} -> {choked['decision']['verdict']}); reachability OK")

    # ---- chunked-prefill (N4): recovery=0 (naive) must give >= interference than recovery=0.7 ----
    naive = analyze(inst, model, {**wl, "chunked_prefill_recovery": 0.0})["decision"]["interference"]
    chunked = analyze(inst, model, {**wl, "chunked_prefill_recovery": 0.7})["decision"]["interference"]
    assert naive >= chunked, (naive, chunked)
    print(f"calc.py selftest PASS — chunked-prefill: interference naive={naive} >= chunked(0.7)={chunked}")

    # ---- HELP/NO-OP/REGRESS vs measured reality ----
    # KEY PHYSICS (the honest headline): at the HOMOGENEOUS 1P:1D floor AS MODELED HERE, disaggregation is a
    # LATENCY play, not a cost play. COST = uplift/2 with uplift = 1/(1-0.5*interference) capped by
    # interference<=(1-cpr)=0.3, so cost tops out at 0.588x — disagg regresses on $/token at this floor (2x
    # GPUs is a hard 2x; the interference uplift caps ~1.18x). TTFT regresses (KV hop on the first-token path);
    # ITL is the axis disagg helps (removes co-batch interference). So a floor verdict is typically MIXED:
    # trade cost+TTFT for ITL. Matches the MEASURED 550B (agg beat disagg 2.1x on cost).
    # SCOPE (consensus-dialectic 2026-06-17, docs/CONSENSUS-2026-06-17): this is NOT a universal — it's the
    # homogeneous-1P:1D L0 screen. Heterogeneous P:D right-sizing (DistServe) AND decode-batch-memory isolation
    # (a dedicated decode pool frees the KV budget the prefill activations cannibalized, raising decode batch at
    # fixed SLO) can make disagg cost-neutral-or-winning WITHOUT this floor's 2x penalty — that axis lives in
    # pd_pool_scaling.py, not here. Read the cost verdict as "for the as-modeled floor," not "for disagg in general."
    dva = r["disagg_vs_agg"]
    cost_sp = dva["axes"]["cost_per_token"]["speedup_disagg_over_agg"]
    assert dva["axes"]["cost_per_token"]["band"] == "regresses", dva["axes"]["cost_per_token"]
    assert 0.45 <= cost_sp <= 0.61, cost_sp                    # ~0.5-0.59 => disagg costs ~2x => regress ~2x (matches measured)
    assert dva["axes"]["ttft"]["band"] == "regresses", dva["axes"]["ttft"]        # KV hop on first-token path
    assert dva["overall"] in ("regresses", "mixed"), dva["overall"]
    # prefill-heavy agent workload: the ITL axis must HELP (more interference to remove than short chat).
    agent = analyze(INSTANCES["p5.48xlarge"], sm, {"isl": 8192, "osl": 64, "instance_name": "p5.48xlarge"})["disagg_vs_agg"]
    assert agent["axes"]["itl"]["band"] == "helps", agent["axes"]["itl"]
    assert agent["axes"]["itl"]["speedup_disagg_over_agg"] >= dva["axes"]["itl"]["speedup_disagg_over_agg"], \
        (agent["axes"]["itl"], dva["axes"]["itl"])             # longer-prefill agent helps ITL >= short chat
    # every axis speedup positive + finite; bands valid
    for k, a in dva["axes"].items():
        assert a["speedup_disagg_over_agg"] > 0 and a["band"] in ("helps", "no-op", "regresses"), (k, a)
    print(f"calc.py selftest PASS — help/regress: 550B cost={cost_sp}x (regresses, matches measured 2.1x agg-win), "
          f"ttft regresses, ITL={dva['axes']['itl']['speedup_disagg_over_agg']}x ({dva['axes']['itl']['band']}) "
          f"=> overall {dva['overall']}; agent ISL8192 ITL helps {agent['axes']['itl']['speedup_disagg_over_agg']}x "
          f"(disagg = latency play, not cost play, at the 1P:1D floor)")

    # ---- DeepSeek-V3 (MoE+MLA): active 37B compute, total 671B memory, MLA KV << naive GQA ----
    ds = {"name": "deepseek-v3", "family": "moe-mla", "params_total_B": 671, "params_active_B": 37, "n_layers": 61,
          "n_heads": 128, "n_kv_heads": 128, "hidden": 7168, "head_dim": 56, "kv_compression": "mla",
          "kv_lora_rank": 512, "weight_dtype": "fp8", "tp": 8, "max_ctx": 163840}
    rd = analyze(INSTANCES["p6-b200.48xlarge"], ds, {"isl": 4096, "osl": 512, "instance_name": "p6-b200.48xlarge"})
    naive_kv = 2 * 128 * 56 * 61 * 1
    assert rd["kv"]["attn_bytes_per_token"] < naive_kv, (rd["kv"]["attn_bytes_per_token"], naive_kv)
    assert rd["memory_fit"]["weights_GB"] == 671.0, rd["memory_fit"]
    print(f"calc.py selftest PASS — DeepSeek-V3(MLA)/b200 verdict={rd['decision']['verdict']} "
          f"MLA-KV={rd['kv']['attn_bytes_per_token']}B/tok (naive GQA would be {naive_kv}) weights={rd['memory_fit']['weights_GB']}GB(fp8)")
    return 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--instance", choices=list(INSTANCES))
    ap.add_argument("--config", help="JSON {model:{...}, workload:{...}}")
    ap.add_argument("--out")
    a = ap.parse_args()
    if a.selftest:
        sys.exit(_selftest())
    if not (a.instance and a.config):
        ap.error("--instance and --config required (or --selftest)")
    cfg = json.load(open(a.config))
    wl = cfg["workload"]; wl["instance_name"] = a.instance
    res = analyze(INSTANCES[a.instance], cfg["model"], wl)
    js = json.dumps(res, indent=2)
    if a.out: open(a.out, "w").write(js)
    print(js)
