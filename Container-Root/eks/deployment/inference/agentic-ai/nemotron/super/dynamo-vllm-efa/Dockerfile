# Nemotron 3.5 Super VL on Dynamo 1.5.0 (-efa base) + vLLM 0.28.0 — golden image.
#
# Author: Anton Alexander
#
# Covers: single-node aggregated, single-node-per-role P/D disagg (NIXL LIBFABRIC), and
# the E+PD multimodal split. NO patches/ layer: unlike ../../ultra (whose golden image
# carries the 0.26-era pipeline-parallel NIXL patches), every Super-VL shape is PP1 on a
# single node per role, and no defect requiring a source patch has been verified on this
# base for this model. NO ray layer either: ray exists in ultra's image solely for PP>1
# aggregated, which this tree does not ship (measured on this base 2026-10-06: ray ABSENT,
# and nothing here needs it).
#
# ---------------------------------------------------------------------------------------
# BASE: 1.5.0-efa. Verified contents (docker image inspect + docker run, 2026-10-06) —
# this drove which golden layers survived from the ultra recipe and which were retired.
# Golden-rule: do NOT assume a newer base fixes a layer — measure it.
#
#     vllm 0.28.0 | ai-dynamo 1.5.0 | nixl 1.3.2 (libplugin_LIBFABRIC.so present)
#     transformers 5.14.1 (>= 5.13 NemotronH inspection requirement: assert, no pin)
#     flashinfer-jit-cache 0.6.16.post3+cu130 == flashinfer-python 0.6.16.post3 ->
#       skew fence stays retired (matched pair)
#     EFA installer 1.50.0 BAKED (+ /opt/amazon/ofi-nccl) -> assert-only
#     runai-model-streamer 0.16.1 present -> LOAD_FORMAT=runai_streamer valid
#     vllm-omni 0.28.0rc1 present -> VLLM_OMNI_USE_QUACK_FP8=0 manifests stay relevant
#     registry: NemotronH_Super_Omni_Reasoning_V3 REGISTERED, bare
#       NemotronH_Omni_Reasoning_V3 NOT (first registered in vLLM v0.29.0) -> the
#       manifests' --hf-overrides alias is REQUIRED on this base; asserted below
#     nemotron_h_mtp in MTPModelTypes -> SPEC_DECODE toggle structurally valid
#     nats-server STILL baked (17 MB)            -> CVE removal layer KEPT
#     etcd/etcdctl/etcdutl STILL baked (61 MB)   -> CVE removal layer KEPT
#     apt launchpadlib chain STILL baked (python3-cryptography 41.0.7 et al) -> KEPT
#     mooncake-transfer-engine ABSENT            -> ultra's 4c layer RETIRED (assert)
#     /opt/uv/cache ABSENT                        -> ultra's 4d layer RETIRED (assert)
#     venv cryptography 50.0.0                    -> ultra's 4f layer RETIRED (assert)
#     flashinfer_cubin/cubins WRITABLE by uid 1000 (gid 0, mode 775 group-write;
#       mkdir test PASSED)                        -> ultra's chmod layer RETIRED (assert)
#     default USER dynamo (uid 1000, gid 0); NO /opt/dynamo/venv (system python)
# ---------------------------------------------------------------------------------------
ARG BASE=nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.5.0-efa
FROM ${BASE}

USER root
SHELL ["/bin/bash", "-c"]

# ---- 0) Assert the base is what we think it is ---------------------------------------
#    Every layer verdict below was measured on vllm 0.28.0 / ai-dynamo 1.5.0. If a future
#    BASE arg moves either, the measurements are void: fail at build, not at serve.
#    The Super-VL-specific asserts (registry alias, MTP method) are what make this image
#    THIS MODEL's golden image rather than a generic runtime.
RUN set -eux; \
    python3 - <<'PY'
import importlib.metadata as m
v = m.version("vllm");      assert v.startswith("0.28"), f"base vllm {v} != 0.28.x"
d = m.version("ai-dynamo"); assert d.startswith("1.5"),  f"base ai-dynamo {d} != 1.5.x"
t = tuple(int(x) for x in m.version("transformers").split(".")[:2])
assert t >= (5, 13), f"base transformers {m.version('transformers')} < 5.13 (NemotronH inspection)"
fi_py  = m.version("flashinfer-python")
fi_jit = m.version("flashinfer-jit-cache").split("+")[0]
assert fi_py == fi_jit, f"flashinfer skew {fi_py} != {fi_jit}"
m.version("runai-model-streamer")  # LOAD_FORMAT=runai_streamer in every .env
from vllm.model_executor.models.registry import ModelRegistry
archs = ModelRegistry.get_supported_archs()
assert "NemotronH_Super_Omni_Reasoning_V3" in archs, \
    "Super Omni arch alias missing from the vLLM registry - the manifests' --hf-overrides cannot work"
if "NemotronH_Omni_Reasoning_V3" in archs:
    print("[base] NOTE: bare NemotronH_Omni_Reasoning_V3 is registered (vLLM >= 0.29 era base);"
          " the manifests' --hf-overrides alias is now optional")
import typing
from vllm.config.speculative import MTPModelTypes
assert "nemotron_h_mtp" in typing.get_args(MTPModelTypes), \
    "nemotron_h_mtp missing from MTPModelTypes - the SPEC_DECODE toggle would be invalid"
print(f"[base] vllm={v} ai-dynamo={d} transformers={m.version('transformers')} "
      f"flashinfer={fi_py} super-omni-arch+mtp OK")
PY

# ---- 1) AWS EFA userspace + NIXL LIBFABRIC: from the base (assert-only) ---------------
ARG EFA_INSTALLER_MIN=1.50.0
RUN set -eux; \
    test -x /opt/amazon/efa/bin/fi_info || { echo "FAIL: base has no /opt/amazon/efa - use an -efa base tag"; exit 1; }; \
    VER="$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' /opt/amazon/efa_installed_packages | head -1)"; \
    printf '%s\n%s\n' "${EFA_INSTALLER_MIN}" "${VER}" | sort -V -C || { echo "FAIL: base EFA ${VER} < required ${EFA_INSTALLER_MIN}"; exit 1; }; \
    test -f /opt/amazon/ofi-nccl/lib/libnccl-net-ofi.so || { echo "FAIL: aws-ofi-nccl plugin missing from base"; exit 1; }; \
    ls /usr/local/lib/python3.12/dist-packages/nixl_cu*.libs/nixl/libplugin_LIBFABRIC.so >/dev/null 2>&1 \
      || { echo "FAIL: NIXL LIBFABRIC plugin missing - disagg kv-transfer backends=[LIBFABRIC] cannot work"; exit 1; }; \
    echo "${VER}" > /opt/efa-installer.version; \
    /opt/amazon/efa/bin/fi_info --version
# The base bakes the bits but NOT the env contract - the manifests carry FI_*/NCCL_* env.

# ---- 2) CVE remediation: drop worker-UNUSED binaries ----------------------------------
#    Same principle as ../../ultra: REMOVE (not .trivyignore) anything the workers never
#    execute, so the CVE gate stays honest. Presence of each carrier was MEASURED on this
#    base 2026-10-06; the retired ultra layers (mooncake, uv cache, venv cryptography,
#    cubin chmod) are asserted-converged in step 3 instead of blindly re-applied.
#
# 2a) nats-server (17 MB): still baked; the deploy uses an EXTERNAL nats pod.
#     Upstream: https://github.com/ai-dynamo/dynamo/issues/12356
RUN rm -f /usr/bin/nats-server || true
# 2b) etcd server binaries (etcd/etcdctl/etcdutl, 61 MB): worker-unused — every template
#     points at an EXTERNAL etcd.
RUN rm -rf /usr/local/bin/etcd
# 2c) apt launchpadlib chain (runtime-unused `add-apt-repository` support; the runtime
#     python resolves /usr/local first, so these were shadowed anyway). Measured present
#     2026-10-06: python3-cryptography 41.0.7, python3-jwt 2.7.0, python3-httplib2 0.20.4,
#     python3-launchpadlib, python3-lazr.restfulclient, python3-oauthlib,
#     software-properties-common.
RUN apt-get remove -y --purge \
      python3-launchpadlib python3-lazr.restfulclient python3-oauthlib \
      python3-jwt python3-httplib2 python3-cryptography \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# ---- 3) Final assert: converged ultra layers stay converged; prerequisites present ----
RUN set -eux; \
    python3 - <<'PY'
import importlib.metadata as m, importlib.util, os, subprocess, tempfile
for p, want in {"vllm": "0.28", "ai-dynamo": "1.5"}.items():
    got = m.version(p); assert got.startswith(want), f"{p} {got} !~ {want}"
assert os.path.exists("/opt/amazon/efa/bin/fi_info"), "EFA userspace missing"
assert not os.path.exists("/usr/bin/nats-server"), "nats-server still present (step 2a)"
assert not os.path.exists("/usr/local/bin/etcd"), "etcd bins still present (step 2b)"
# Converged-in-GA asserts (ultra's 4c/4d/4f layers, retired here — fail loud on regression):
try:
    m.version("mooncake-transfer-engine"); raise AssertionError("mooncake re-appeared - restore ultra's removal layer")
except m.PackageNotFoundError:
    pass
assert not os.path.exists("/opt/uv/cache"), "uv wheel cache re-appeared - restore ultra's removal layer"
cv = tuple(int(x) for x in m.version("cryptography").split(".")[:1])
assert cv >= (50,), f"venv cryptography {m.version('cryptography')} < 50 - restore ultra's bump layer"
# Cubin dir writability for the non-root worker (ultra's chmod layer, retired: measured
# writable on this base). Checked as a REAL write by the dynamo uid, not a mode read.
import flashinfer_cubin
d = os.path.join(os.path.dirname(flashinfer_cubin.__file__), "cubins")
rc = subprocess.run(["su", "dynamo", "-s", "/bin/bash", "-c", f"mkdir '{d}/.writetest' && rmdir '{d}/.writetest'"]).returncode
assert rc == 0, f"{d} not writable by the dynamo user - restore ultra's chmod -R a+rwX layer"
print("[golden-1.5.0-super] agg + P/D disagg + E/PD prerequisites present; EFA present; "
      "worker-unused CVE carriers absent; converged layers verified still converged")
PY

USER dynamo
LABEL org.opencontainers.image.description="Golden-image 1.5.0 for Nemotron 3.5 Super VL: Dynamo 1.5.0 (-efa base, EFA 1.50 + NIXL LIBFABRIC baked) + vLLM 0.28.0 (NemotronH Super Omni arch alias + nemotron_h_mtp asserted) + CVE remediation (nats/etcd/launchpadlib removed); no source patches, no ray (single-node shapes only; Dockerfile-only reproducible)"
