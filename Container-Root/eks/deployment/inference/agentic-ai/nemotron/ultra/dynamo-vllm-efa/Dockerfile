# Nemotron-550B on Dynamo 1.4.0 (-efa base) + vLLM 0.26 — 1.4.0-efa VARIANT of the golden image.
#
# Author: Anton Alexander
#
# Covers: aggregated, EP16 (DP2/TP8), and hybrid-Mamba disagg (NIXL) at PP1.
# NOT covered (vs the 1.3.1 golden): PP>1 DISAGG. The vLLM PR#48263 overlay + PP1 fix
# (golden steps 3/3b) were built against the 0.23-era nixl connector package (v4->v8);
# vLLM 0.26.0 rewrote that package (base_worker/push_worker/pull_worker/tp_mapping,
# NIXL_CONNECTOR_VERSION=5) and the overlay files CANNOT drop onto it. Track #48263 —
# when its successor lands against 0.26+, re-add a measured overlay stage.
#
# WHY the overlay retirement is safe at PP1 — MEASURED, not assumed (nixl-ep-297,
# 2026-08-20): 550B Nemotron-3-Ultra disagg (prefill TP8 + decode TP8, 2x p5en) on the
# STOCK 1.4.0-efa image under Grove/kai served coherent completions with KV-over-EFA
# verified (decode rdma_read +3.061 GB == 48x60.82 MB NIXL telemetry to 0.0015%). The
# 0.23-era PP1 idx192 fast-path overflow does NOT reproduce on 0.26.
#
# ---------------------------------------------------------------------------------------
# BASE: 1.4.0-efa. Verified contents (docker run --rm, 2026-08-21) — this drove which
# golden layers survived and which were retired. Golden-rule: do NOT assume a newer base
# fixes a layer — measure it.
#
#     vllm 0.26.0 | ai-dynamo 1.4.0 | nixl 1.3.1 (pip; NGC label says 1.3.2)
#     transformers 5.14.1 -> the 5.13.0 pin layer RETIRED (>=5.13 NemotronH inspection
#       requirement CONVERGED by GA; assert below, no pin)
#     flashinfer-jit-cache 0.6.14+cu130 == flashinfer-python 0.6.14 -> skew fence stays
#       retired (matched pair, same as 1.3.1)
#     EFA installer 1.49.0 BAKED (+ /opt/amazon/ofi-nccl) -> assert-only, same as golden
#     ray ABSENT (never shipped by any NGC base) -> install layer KEPT for PP>1 agg
#     nats-server 17.5MB STILL baked (GA did NOT converge) -> CVE removal layer KEPT
#     nixl connector: PACKAGE layout, NIXL_CONNECTOR_VERSION=5, NO ssm_conv_transfer_utils
#       (that file exists on vllm main, NOT in shipped 0.26.0 — corrected 2026-08-21)
#     flashinfer_cubin/cubins root:root 775, uid-1000 write FAILS (measured) -> NVFP4
#       cubin-dir fix layer KEPT
#     default USER dynamo (uid 1000)
# ---------------------------------------------------------------------------------------
ARG BASE=nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.4.0-efa
FROM ${BASE}

USER root
SHELL ["/bin/bash", "-c"]

# ---- 0) Assert the base is what we think it is ---------------------------------------
#    Every layer verdict below was measured on vllm 0.26.0 / ai-dynamo 1.4.0. If a future
#    BASE arg moves either, the measurements are void: fail at build, not at serve.
#    transformers is asserted here too (>=5.13 needed to inspect NemotronHForCausalLM;
#    GA ships 5.14.1 so this is an assert, not a pin — a base regression fails loud).
RUN set -eux; \
    python3 - <<'PY'
import importlib.metadata as m
v = m.version("vllm");      assert v.startswith("0.26"), f"base vllm {v} != 0.26.x"
d = m.version("ai-dynamo"); assert d.startswith("1.4"),  f"base ai-dynamo {d} != 1.4.x"
t = tuple(int(x) for x in m.version("transformers").split(".")[:2])
assert t >= (5, 13), f"base transformers {m.version('transformers')} < 5.13 (NemotronH inspection)"
fi_py  = m.version("flashinfer-python")
fi_jit = m.version("flashinfer-jit-cache").split("+")[0]
assert fi_py == fi_jit, f"flashinfer skew {fi_py} != {fi_jit} — re-add FLASHINFER_DISABLE_VERSION_CHECK fence (dynamo#12355)"
print(f"[base] vllm={v} ai-dynamo={d} transformers={m.version('transformers')} flashinfer={fi_py} OK")
PY

# ---- 1) AWS EFA userspace: from the base (assert-only; install layer retired at 1.3.1) -
ARG EFA_INSTALLER_MIN=1.49.0
RUN set -eux; \
    test -x /opt/amazon/efa/bin/fi_info || { echo "FAIL: base has no /opt/amazon/efa - use an -efa base tag or restore the efa_installer.sh layer (see ai-dynamo/dynamo#12105)"; exit 1; }; \
    VER="$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' /opt/amazon/efa_installed_packages | head -1)"; \
    printf '%s\n%s\n' "${EFA_INSTALLER_MIN}" "${VER}" | sort -V -C || { echo "FAIL: base EFA ${VER} < required ${EFA_INSTALLER_MIN}"; exit 1; }; \
    test -f /opt/amazon/ofi-nccl/lib/libnccl-net-ofi.so || { echo "FAIL: aws-ofi-nccl plugin missing from base"; exit 1; }; \
    echo "${VER}" > /opt/efa-installer.version; \
    /opt/amazon/efa/bin/fi_info --version
# The base bakes the bits but NOT the env contract - keep ours.
ENV FI_PROVIDER=efa FI_EFA_USE_DEVICE_RDMA=1 \
    NCCL_NET_PLUGIN=ofi NCCL_NVLS_ENABLE=0

# ---- 2) Scenario deps GA does NOT satisfy: ray only ----------------------------------
#    ray: PP>1 agg needs `--distributed-executor-backend ray`. ABSENT from every NGC base
#    to date — never a regression, just never shipped. 2.55.1 is the PP2-proven pin from
#    the 0.23-era golden; import-verified here, ray-under-0.26 gets its real gate at the
#    E2E smoke (a version bump, if needed, must be measured — not assumed).
#    transformers pin RETIRED: GA 5.14.1 >= 5.13 (asserted in step 0).
RUN set -eux; \
    pip install --no-cache-dir "ray==2.55.1"; \
    python3 - <<'PY'
import importlib.metadata as m
assert m.version("ray") == "2.55.1", m.version("ray")
assert m.version("vllm").startswith("0.26"), "ray install drifted vllm off 0.26.x"
import ray  # import, not just metadata — a broken wheel passes a version check
print("[deps] ray=2.55.1 installed, vllm intact")
PY

# ---- 3) nixl connector: STOCK (overlay + PP1 fix RETIRED at 0.26) ---------------------
#    Golden steps 3/3b deleted per the header. Assert the layout we measured so a future
#    base swap that changes the connector fails here, not on a p5en at serve time.
RUN set -eux; \
    python3 - <<'PY'
import importlib.util, os, re
b = importlib.util.find_spec("vllm").submodule_search_locations[0]
nixl = os.path.join(b, "distributed", "kv_transfer", "kv_connector", "v1", "nixl")
assert os.path.isdir(nixl), "nixl connector package missing — base layout changed, re-measure"
src = open(os.path.join(nixl, "metadata.py")).read()
mm = re.search(r"NIXL_CONNECTOR_VERSION.*?=\s*(\d+)", src)
assert mm and int(mm.group(1)) >= 5, f"connector version {mm and mm.group(1)} < 5 — pre-0.26 layout, the PP1-hybrid stock-proof (nixl-ep-297) does not apply"
print(f"[nixl] stock package connector v{mm.group(1)} (PP1 hybrid disagg stock-proven 2026-08-20)")
PY

# ---- 4) CVE remediation: drop worker-UNUSED /usr/bin/nats-server ----------------------
#    STILL baked in 1.4.0-efa (17.5MB, measured 2026-08-21) — GA has not converged this.
#    The deploy uses an EXTERNAL nats pod; removal (not .trivyignore) keeps the
#    0-CRITICAL claim honest. Upstream: https://github.com/ai-dynamo/dynamo/issues/12356
RUN rm -f /usr/bin/nats-server || true

# ---- 5) Final assert: every scenario's prerequisites present in ONE image -------------
RUN set -eux; \
    python3 - <<'PY'
import importlib.metadata as m, importlib.util, os
need = {"vllm": "0.26", "ai-dynamo": "1.4", "ray": "2.55.1"}
for p, want in need.items():
    got = m.version(p); assert got.startswith(want), f"{p} {got} !~ {want}"
b = importlib.util.find_spec("vllm").submodule_search_locations[0]
assert os.path.isdir(os.path.join(b, "distributed/kv_transfer/kv_connector/v1/nixl")), "nixl connector package missing"
assert os.path.exists("/opt/amazon/efa/bin/fi_info"), "EFA userspace missing"
assert not os.path.exists("/usr/bin/nats-server"), "nats-server still present (CRITICAL CVE)"
print("[golden-1.4.0] agg + EP16 + PP1-hybrid-disagg prerequisites present; EFA present; "
      "0-CRITICAL precondition met; PP>1 disagg NOT covered (see header)")
PY

# ---- 6) NVFP4 fix: make flashinfer's cubin package dir writable -----------------------
#    Measured on THIS base 2026-08-21: cubins/ is root:root 775 with 5 baked entries and
#    a uid-1000 mkdir into it FAILS -> the non-root `dynamo` worker would PermissionError
#    at the first NVFP4 MoE call (SM100/B200), exactly as on 1.3.1. Same recipe as the
#    golden: chmod -R, and do NOT pre-create the flashinfer/trtllm subtree (a pre-created
#    root-owned subtree re-breaks the symlink path — verified regression in the first cut
#    of the 1.3.1 step). BF16 unaffected.
RUN set -eux; \
    CUBINS="$(python3 -c 'import os,flashinfer_cubin; print(os.path.join(os.path.dirname(flashinfer_cubin.__file__),"cubins"))')"; \
    mkdir -p "${CUBINS}"; \
    chmod -R a+rwX "${CUBINS}"; \
    test -w "${CUBINS}"; \
    echo "[nvfp4-cubin-fix] ${CUBINS} made writable (chmod -R a+rwX; flashinfer/ subtree left for the worker to own)"

USER dynamo
LABEL org.opencontainers.image.description="Golden-image 1.4.0 variant: Dynamo 1.4.0 (-efa base, EFA 1.49 baked) + vLLM 0.26 stock nixl connector v5 + ray 2.55.1 (agg + EP16 + PP1 hybrid-Mamba disagg; PP>1 disagg pending a 0.26-era #48263 successor; Dockerfile-only reproducible)"
LABEL org.opencontainers.image.source="https://github.com/vllm-project/vllm/pull/48263"
