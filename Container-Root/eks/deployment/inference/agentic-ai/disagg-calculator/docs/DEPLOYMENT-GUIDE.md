# Deployment guide: aggregation vs disaggregation, end-to-end

*Author: Anton Alexander*  


A decision-then-deploy runbook. You start with a model + an SLA + a budget, and finish with a deployed,
benchmarked Dynamo serving config — having spent GPU hours **only where the cheap analytical layers said to**.

The question this guide answers in deployment terms: **for MY model, instance, SLA, and budget — do I
aggregate or disaggregate prefill/decode, and what does each cost per million tokens?**

> Latency and cost can disagree. Disaggregation often wins on **TTFT / SLA-attainment** while
> **aggregation wins on $/Mtok** (disagg needs ≥2× the GPUs). This guide makes both explicit so you choose
> on YOUR priority (tail-latency SLA vs unit cost). The `cost.py` tool quantifies the tradeoff.

> **Scope of this directory.** What ships here is the **analytical layer** (`analyze/calc.py` +
> `calibration.py`) and the two browser pages — the cheap, run-anywhere screening tool. This runbook also
> references the optional **live-sweep harness** (`driver/sweep.py`, `driver/goodput.py`, `cost.py`,
> `render_charts.py`) and the L3 GPU benchmarking steps; those are the deeper research layer and live in the
> companion research harness (not required to use the calculator).
> You do **not** need them to use the calculator — they're how the calculator gets calibrated against real
> GPUs. Steps 0, 2 (L0), and 7 are self-contained here; steps 1, 3–6 point at the companion harness or
> upstream tooling.

---

## Rule of thumb: disaggregate, or run multiple aggregated replicas?

The single most-asked question. Short version, surfaced by the calculator + our measured 550B/70B runs:

| Choose… | When | Why |
|---|---|---|
| **Multiple aggregated replicas** | short-context chat · prefill cheap vs decode · cost/throughput-bound · loose-to-moderate ITL SLO | At the homogeneous 1P:1D floor, disagg buys ~nothing but costs **≥2× the GPUs** → unit-cost regresses (efficiency caps ≈0.5–0.59×). Just scale replicas. |
| **Disaggregate (split prefill/decode)** | long input contexts (RAG, agents, code) · prefill heavy vs decode · **tight TPOT/ITL SLO** · you can right-size the prefill:decode pool ratio | A prefill burst stalls the decode stream of every co-batched request; splitting removes that **TPOT interference**. This is the one axis disagg wins. |

**Per-axis truth (so nobody is surprised):** moving agg→disagg **regresses cost** (extra GPUs) and **regresses TTFT** (adds a KV-transfer hop); **ITL is the only axis it improves**, and only when prefill interference is high. So disaggregation is fundamentally a **latency play, not a cost play** — *unless* you also right-size the P:D ratio (e.g. 1P:3D) and isolate decode-batch memory, which is what opens disagg's cost case (DistServe, arXiv:2401.09670; Splitwise, 2.35×).

**Measured anchor (not taken on faith):** Nemotron-3 Ultra 550B, p5en, short chat (ISL512/OSL128, low concurrency) → **aggregation 2.1× cheaper** ($95.88 vs $202.71/Mtok), triangulated by NVIDIA aiconfigurator (1.77×) and our analytic optimizer. At HIGH concurrency the gap narrows (interference grows) — confirm at your real load with the L3 sweep below.

**TL;DR:** tight-ITL + long prompts + can right-size pools → **disaggregate**. Cost-sensitive + short context + simpler ops → **aggregated replicas**. When in doubt, the L0 screen (`calc.py` / `web/index.html`) returns the verdict + the help/no-op/regress breakdown per axis in one shot, before you spend a GPU-hour.

---

## 0. Prerequisites (once per cluster)
- EKS cluster with GPU nodes (p5/p5en/p6-b200), EFA device plugin, FSx (weights), dynamo-platform (etcd+NATS).
- `pip install aiconfigurator aiperf` (or use the Dynamo container which bakes both).
- This repo: `analyze/` (calc, cost, charts, vision) + `driver/` (sweep, goodput) + `deploy/templates/`.

## 1. Build the images (chain of custody)
The serving image is a thin overlay chain — build once, reuse for agg AND disagg (same image, different args).
The disaggregation-capable serving image = the public NGC vLLM-runtime + EFA + the NVIDIA Nemotron-Ultra
disagg patch series (which removes the `External KV connector is not verified yet` assert and adds the
SSM tail-align). The companion [Nemotron 3 Ultra](../../nemotron/ultra) deployment in this project ships the
Dockerfile and a pre-built public image:
```
# from the nemotron/ultra disagg build dir — see ../../nemotron/ultra/disagg
docker build -t <your-registry>/dynamo-vllm-efa:disagg \
  -f ../../nemotron/ultra/disagg/dynamo-vllm-efa/Dockerfile .
```
A pre-built, anon-pullable image is referenced from the [Nemotron 3 Ultra README](../../nemotron/ultra):
`public.ecr.aws/hpc-cloud/dynamo-vllm-efa:disagg-1.2.0`.
**Agg vs disagg is NOT a different image** — it's `--disaggregation-mode {prefill|decode}` + topology in the YAML.

## 2. SCREEN before you spend GPUs — L0 (instant, this repo)
```
cat > m.json <<'J'
{"model":{"name":"my-model","family":"dense","params_B":70,"n_layers":80,"n_heads":64,"n_kv_heads":8,
          "hidden":8192,"head_dim":128,"weight_dtype":"bf16","tp":8},
 "workload":{"isl":4096,"osl":512,"ttft_s":2.0,"tpot_ms":50}}
J
python3 analyze/calc.py --instance p5en.48xlarge --config m.json --out a.json    # latency verdict
python3 analyze/cost.py --instance p5en.48xlarge --config m.json                 # $/Mtok agg vs disagg
python3 analyze/render_charts.py --instance p5en.48xlarge --config m.json --outdir charts/
python3 analyze/visual_verdict.py --charts 'charts/*.png' --analysis a.json      # vision LLM confirms
```
Read the two verdicts:
- `calc.py` → **latency** verdict (disagg if cheap KV transfer + high prefill interference).
- `cost.py` → **cost** verdict ($/Mtok agg vs disagg + savings %). If they disagree, that's your tradeoff to own.
Or open `web/index.html` (interactive, no keys) for the same, live.

## 3. RECOMMEND parallelism — L1 aiconfigurator (offline, profiled, emits Dynamo YAML)
```
aiconfigurator cli default --model-path <hf-id> --total-gpus 16 --system h200_sxm --backend vllm \
   --ttft 2000 --tpot 50 --isl 4096 --osl 512 --save-dir reco/
# emits reco/{agg_config.yaml, prefill_config.yaml, decode_config.yaml, k8s_deploy.yaml, bench_run.sh}
```
aiconfigurator is upstream NVIDIA tooling ([github.com/ai-dynamo/aiconfigurator](https://github.com/ai-dynamo/aiconfigurator)).
This gives the real TP/PP/EP and prefill:decode worker ratio (`R_PD`) — better than the L0 1:1 assumption.

## 4. RENDER the deploy YAMLs
- Disagg (proven, unprivileged, no-hostNetwork): `deploy/templates/pp1-disagg.nohostnet.yaml`
  (TP8/PP1, NixlConnector + LIBFABRIC, EFA env, `imagePullPolicy: Always`, IPC_LOCK — Alex's publication standard).
- Agg: same image, single deployment, no `--disaggregation-mode`.
- Or use aiconfigurator's `k8s_deploy.yaml` from step 3 (Dynamo DGD).

## 5. CALIBRATE the fabric — L2 nixlbench (one run per instance+backend)
The biggest L0 unknown is achieved KV-transfer GB/s. Measure it, then feed it back so every estimate tracks YOUR fabric:
```
# nixlbench ships with NIXL (github.com/ai-dynamo/nixl); run its p2p KV bandwidth sweep over EFA:
nixlbench --etcd-endpoints <etcd-url> --backend Libfabric --initiator_seg_type VRAM \
  --target_seg_type VRAM --op_type WRITE
```
Update `analyze/calc.py` `CAL["kv_transfer_efficiency"]` / `TIERS[...]["GBs"]` with the measured number.

## 6. CONFIRM on real GPUs — L3 AIPerf goodput (the ground truth)
Deploy the top-1 agg and top-1 disagg configs, benchmark each at the FRONTEND, get goodput-under-SLA:
```
driver/run_cell.sh my-model "mode=disagg,R_PD=1:1,..." ~/.kube/config-cgk    # deploy+bench+capture+teardown
# or Dynamo-native: kubectl apply -f benchmarks/incluster/benchmark_job.yaml
# goodput = max QPS sustaining >=90% joint (TTFT,TPOT) attainment:
python3 driver/goodput.py --runs runs.json --ttft-slo-s 2.0 --tpot-slo-ms 50
```

## 7. DECIDE on cost+SLA — feed MEASURED goodput into cost.py
```
python3 analyze/cost.py --instance p5en.48xlarge --config m.json \
   --agg-goodput <measured_agg_tok_s> --disagg-goodput <measured_disagg_tok_s> \
   --price-per-hr <your_rate_if_capacity_block>      # default = live AWS on-demand
```
Output: $/Mtok for agg vs disagg, cheaper-at-SLA, savings %, and the latency-vs-cost note. **This is the
deployment decision artifact** — pair it with the SLA-attainment from step 6.

## 8. DEPLOY the winner
`kubectl apply -f <chosen YAML>` (or the aiconfigurator DGD). Re-run step 6 in your live environment periodically; pod-freshness
matters (a stale pod can show 4× worse latency — restart before trusting a baseline).

---

## Worked decision (Nemotron-3 Ultra 550B, p5en, ISL512/OSL128, SLA 2s/120ms)
- L0 latency verdict: **disaggregate** (fav 0.573 — cheap KV transfer, high prefill interference).
- cost.py (measured low-conc goodput): agg **$98/Mtok** vs disagg **$196/Mtok** → **aggregation cheaper** here.
- **Decision:** if your SLA is TTFT-bound (interactive chat) → disaggregate (proven: 486MB KV/req over EFA,
  ITL flat 77ms). If your SLA is loose and you optimize $/token at low concurrency → aggregate. At HIGH
  concurrency the disagg cost gap closes (interference grows) — confirm with an L3 sweep at your real load.

## Parallelism status: independent P/D scaling ships at PP1; PP>1 is the can't-fit-one-node case

**Independent prefill/decode scaling is the whole point of disaggregation — and it does NOT require PP>1.**
It comes from **replica count**, not pipeline parallelism. Prefill and decode are separate workloads, each
independently scalable, and the Dynamo router sprays across each pool.

**Use LWS (LeaderWorkerSet) for disagg, not plain Deployments** — that's the right primitive and the answer
is "yes, stick with LWS":
- A **single-node role** (TP8/PP1, one node) maps to an LWS group of size 1 (leader only). Scaling the pool
  = LWS `replicas:`. This is interchangeable with a Deployment here, but LWS keeps prefill and decode as
  uniform, named, gang-scheduled groups — cleaner and consistent with the multi-node case.
- A **multi-node role** (TP8/PP2, role spans 2 nodes) *requires* LWS: the group is leader + worker(s),
  gang-scheduled, with the stable leader DNS the engine's Ray/torch-dist bootstrap needs. A Deployment can't
  express "these N pods are one gang-scheduled replica." This is exactly the topology running live on cgk
  today (`nemotron3-ultra-550b-disagg-{prefill,decode}-0` + `-0-1` = LWS leader+worker per role).

To run 16 GPUs of prefill and 32 of decode (PP1, single-node roles):

```
prefill LWS = 2 × (TP8/PP1 group, size 1) = 16 GPUs   # prefill LWS replicas: 2
decode  LWS = 4 × (TP8/PP1 group, size 1) = 32 GPUs   # decode  LWS replicas: 4  → asymmetric 1:2 P:D, zero PP
```

That asymmetric pool sizing is exactly the `R_PD` axis (`pd_pool_scaling.py` models it: goodput =
`max over p of min(p·prefill_rate, (R−p)·decode_rate)`). **No PP needed** — each replica is one TP8/PP1 node.

- **Tensor-parallel >1 is NOT blocked.** The shipping, proven unit is **TP8 / PP1** (one node per role):
  verified E2E on p5en — coherent chat + **486 MB KV-over-EFA/request**, ITL flat ~77 ms. 550B fits one
  p5en node at TP8, so a prefill (or decode) replica = one node, and you scale pools by `replicas:`.
- **Status of independent pool scaling:** architecturally supported + proven at the 1:1 floor. The N:M-replica
  case (e.g. 1P:2D) is the one open *validation* — but it's just more replicas of the proven TP8/PP1 unit,
  no known blocker, and **not** the PP bug below.

**When PP>1 IS required** (and currently blocked on hybrid-Mamba): only when a **single replica of a role
can't fit one node's TP domain** — e.g. a model too large for one node even at max TP (550B on H100's
640 GB/node, or a larger future model on p5en). It is NOT required for asymmetric P:D pool scaling. The
blocker is an open vLLM bug ([#43368](https://github.com/vllm-project/vllm/issues/43368)): NIXL
member-identity routing is disabled for Mamba (`_use_member_identity`→`False` when `_has_mamba`), so the
hybrid-Mamba region groups collapse and the decode worker reads the wrong SSM region → **degenerate output**
(not a hang; KV *does* transfer). Dense/MoE models are unaffected — PP>1 works for them.

- **Unblock path (staged, not yet merged):** a minimal `_ssm_layer_names()` filter so SSM descriptors land at
  the right offsets — static-verified, cluster-E2E pending a 4-node p5en window. Tracked in
  [`docs/DISAGG-PR-LEDGER.md`](DISAGG-PR-LEDGER.md). The PR author deferred the upstream fix (hybrid E2E was
  never validated upstream), so this is a high-value contribution-in-progress.
- **For the blog / the standard:** independent prefill/decode scaling ships **today at PP1 via replicas**.
  Reach for PP>1 only when one replica can't fit one node — for 550B at TP8 on p5en, that case doesn't arise.

## The fit squeeze: 550B BF16 "barely fits" one node — and the two escapes

A fair objection (Alex, 2026-06-18): 550B BF16 *technically* fits one p5en, but the settings to make it fit
**degrade the model**, which can defeat the point of disaggregating. The calculator quantifies it
(`analyze/calc.py`, now PP-aware), 550B on p5en at the RAG workload ISL8192/OSL512:

| Topology | GPUs | weight-util | KV budget | CUDA graphs | conc. ceiling |
|---|---|---|---|---|---|
| **BF16 TP8 / PP1** (1 node, ships today) | 8 | **0.97** | ~5 GB | ❌ enforce-eager | **~1** |
| **BF16 TP8 / PP2** (2 nodes per role) | 16 | 0.49 | ~1111 GB | ✅ | ~272 |
| **FP8 TP8 / PP1** (1 node, quantized) | 8 | 0.49 | ~555 GB | ✅ | ~272 |

At BF16/PP1 the weights eat **97.5%** of HBM → ~one long request fits, no CUDA graphs (`--enforce-eager`),
`--max-model-len` and `--gpu-memory-utilization` pushed to the edge. That IS a degraded operating point.
**Three ways out, all restore CUDA graphs + large KV headroom — and the best one is LIVE-PROVEN on H200:**

0. **★ Official NVFP4 checkpoint — `nvidia/...-550B-A55B-NVFP4` (LIVE-PROVEN on p5en/H200, 2026-06-19).**
   322 GB ModelOpt MIXED_PRECISION ckpt → fits **TP8 on ONE node, no PP, no 2nd node**. Live probe on cgk
   (vLLM 0.20.1): loaded 41.34 GiB/GPU, **81.83 GiB free for KV → 1374× conc @2K**, coherent output. This is
   the cleanest single-node fix — and it's an OFFICIAL NVIDIA artifact, not a self-quant. *Earlier we (and a
   3-LLM quorum) wrongly believed NVFP4 was Blackwell-only; the live test refuted that — the MoE-expert NVFP4
   GEMMs run on SM90 because the rest of the model is FP8/BF16.* Open: throughput vs BF16 (characterizing now).
   `results/nvfp4-probe/`.
1. **Span the model across nodes per role (PP≥2).** PP shards the model's *layers* over `tp·pp` GPUs, so the
   same 1100 GB of weights sit in 2256 GB of aggregate HBM (2 p5en) — weight-util drops to 0.49, KV budget
   jumps to ~1.1 TB, CUDA graphs come back. Cost: 2× GPUs per replica (the calculator's cost axis counts it).
   **This is the LWS path** (a role = a LeaderWorkerSet leader+worker spanning 2 nodes). Blocked on the
   hybrid-Mamba PP bug above for 550B specifically; dense/MoE models can do this today.
2. **Self-quantize to FP8 (ModelOpt).** Halves weights to ~550 GB → fits one node at 0.49 util with the *same*
   KV headroom and CUDA graphs, **no second node**. Trade: produce a validated-accuracy FP8 checkpoint (we
   proved the ModelOpt FP8 *serving path* on p5en, but on Qwen-1.5B — `project A/B validated-FP8-vs-BF16` —
   not yet on 550B). Now mostly redundant with option 0 since the official NVFP4 ckpt already serves.

**Read:** Alex is right that 1-node BF16 is a compromised operating point. The fix is *more aggregate HBM per
replica* — reached either by spanning nodes (PP, the LWS path, pending the Mamba fix for 550B) or by FP8
(available today, one node). The calculator now models both so the trade is explicit, not discovered at deploy.

## Honest scope
- L0/cost are estimators (calibrated to measured 550B/p5en); steps 5-7 replace estimates with measurements.
- p5en price is the AWS capacity-reservation rate ($63.30/hr); pass `--price-per-hr` for your actual contract.
- Disagg needs the dynamo-platform (etcd+NATS) + the patched image; agg can run barer. Factor ops cost too.
- **Topology:** independent P/D scaling = `replicas:` per role at TP8/PP1 (proven unit); PP>1 is only the
  can't-fit-one-node case and is research on hybrid-Mamba (see above).
