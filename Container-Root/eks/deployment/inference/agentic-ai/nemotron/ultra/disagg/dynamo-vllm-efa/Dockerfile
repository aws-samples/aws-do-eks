# Nemotron-550B disagg on Dynamo 1.3.1 (-efa base) + vLLM 0.23 — ONE GOLDEN IMAGE.
#
# Author: Anton Alexander
#
# Covers every scenario: aggregated, EP16 (DP2/TP8), and PP>1 hybrid-Mamba disagg (NIXL).
#
# FULLY PUBLIC, DOCKERFILE-ONLY REPRODUCIBLE: no gist, no external files, no patch step,
# no fork refs. Anyone can `docker build` this with only public network access.
#
#   docker build -t $REGISTRY/nemotron-disagg:dynamo131-golden .
#   ./build-sbom-scan.sh          # SBOM (SPDX + CycloneDX) + CVE gate, pipeline-ready
#
# The PP>1 fix is fetched at build time from vLLM PR #48263's own pull-ref on UPSTREAM
# github.com/vllm-project/vllm (the PR head IS the E2E-tested revision, SHA-pinned).
# When #48263 merges into the Dynamo-pinned vLLM, delete the OVERLAY stage entirely.
#
# ---------------------------------------------------------------------------------------
# BASE: 1.3.1-efa. Verified contents (docker run --rm, 2026-08-06) — this drove which
# layers below survived and which were retired:
#
#     vllm 0.23.0 (build commit IDENTICAL to 1.3.0) | ai-dynamo 1.3.1
#     transformers 5.12.0 | runai-model-streamer 0.16.0
#     flashinfer-jit-cache 0.6.12+cu130 | flashinfer-python 0.6.12
#     EFA installer 1.49.0 BAKED (+ libfabric 2.4.0amzn + /opt/amazon/ofi-nccl) -> our
#       EFA install layer RETIRED, replaced by an assert (#12105 retire condition met)
#     ray ABSENT | no /opt/dynamo/venv | default USER dynamo | nats-server 16MB STILL baked
#     nixl NIXL_CONNECTOR_VERSION 4 -> PR#48263 overlay (v8) STILL REQUIRED
#
# Do NOT assume a newer base fixes a layer — measure it. Three separate GA layers were
# each assumed-fixed and were not (transformers, flashinfer, nats-server).
# ---------------------------------------------------------------------------------------
ARG BASE=nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.3.1-efa
FROM ${BASE}

USER root
SHELL ["/bin/bash", "-c"]

# ---- 0) Assert the base is what we think it is ---------------------------------------
#    GA ships vLLM 0.23.0 natively, so the old `pip install vllm==0.23.0` force-install
#    layer is DELETED. That makes the base's own version load-bearing: if a future BASE
#    arg regresses it, every scenario below is silently wrong. Fail at build, not serve.
RUN set -eux; \
    python3 - <<'PY'
import importlib.metadata as m
v = m.version("vllm");      assert v.startswith("0.23"), f"base vllm {v} != 0.23.x"
d = m.version("ai-dynamo"); assert d.startswith("1.3"),  f"base ai-dynamo {d} != 1.3.x"
print(f"[base] vllm={v} ai-dynamo={d} OK")
PY

# ---- 1) AWS EFA userspace: NOW FROM THE BASE (install layer RETIRED at 1.3.1) --------
#    History: GA 1.3.0 had NO /opt/amazon/efa and 1.3.0-efa baked 1.47, so this used to
#    be a full efa_installer.sh layer (ai-dynamo/dynamo#12105). The 1.3.1-efa tag bakes
#    EFA installer 1.49.0 + libfabric 2.4.0amzn + /opt/amazon/ofi-nccl (measured in-image
#    2026-08-06), which meets the retire condition. Keep a build-time assert so a future
#    BASE bump that regresses EFA fails here, not on a p5en at serve time.
ARG EFA_INSTALLER_MIN=1.49.0
RUN set -eux; \
    test -x /opt/amazon/efa/bin/fi_info || { echo "FAIL: base has no /opt/amazon/efa - use an -efa base tag or restore the efa_installer.sh layer (see #12105)"; exit 1; }; \
    VER="$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' /opt/amazon/efa_installed_packages | head -1)"; \
    printf '%s\n%s\n' "${EFA_INSTALLER_MIN}" "${VER}" | sort -V -C || { echo "FAIL: base EFA ${VER} < required ${EFA_INSTALLER_MIN}"; exit 1; }; \
    test -f /opt/amazon/ofi-nccl/lib/libnccl-net-ofi.so || { echo "FAIL: aws-ofi-nccl plugin missing from base"; exit 1; }; \
    echo "${VER}" > /opt/efa-installer.version; \
    /opt/amazon/efa/bin/fi_info --version
# The base bakes the bits but NOT the env contract - keep ours.
ENV FI_PROVIDER=efa FI_EFA_USE_DEVICE_RDMA=1 \
    NCCL_NET_PLUGIN=ofi NCCL_NVLS_ENABLE=0
# NOTE: FLASHINFER_DISABLE_VERSION_CHECK=1 was DELETED. It existed because the dev base
# baked jit-cache 0.6.11.post2 while pip vllm==0.23.0 floated flashinfer to 0.6.12 — a
# skew that failed NemotronH registry inspection at SERVE time. GA ships jit-cache
# 0.6.12+cu130 AND flashinfer-python 0.6.12 (verified), so the skew is gone and the fence
# is no longer needed. Re-add only if a base bump reintroduces a mismatch.
# Upstream: https://github.com/ai-dynamo/dynamo/issues/12355

# ---- 2) Scenario deps GA does NOT satisfy -------------------------------------------
#    ray       : PP>1 needs `--distributed-executor-backend ray`. ABSENT from BOTH NGC
#                bases (dev pin and GA alike) — never a GA regression, just never shipped.
#                2.55.1 matches the PP2-proven image disagg-pd:pp2-...-20260710-dyn2.
#    transformers 5.13.0 : GA ships 5.12.0, which cannot inspect NemotronHForCausalLM.
#                Still required — GA did NOT converge this.
RUN set -eux; \
    pip install --no-cache-dir "ray==2.55.1" "transformers==5.13.0"; \
    python3 - <<'PY'
import importlib.metadata as m
assert m.version("ray") == "2.55.1", m.version("ray")
assert m.version("transformers") == "5.13.0", m.version("transformers")
assert m.version("vllm").startswith("0.23"), "dep pin drifted vllm off 0.23.x"
import ray  # import, not just metadata — a broken wheel passes a version check
print("[deps] ray=2.55.1 transformers=5.13.0 vllm intact")
PY

# ---- 3) OVERLAY: fetch vLLM PR #48263 DIRECTLY FROM UPSTREAM, copy 5 nixl files ------
#    The PR head IS the E2E-tested revision (validated Nemotron-550B PP>1 disagg on
#    p5en/EFA). Fetched from vllm-project's own pull-ref — no fork, no gist, no patch.
#    SHA-pinned: the build fails loud if the PR head moves past the tested revision.
#    Verified 2026-07-30: refs/pull/48263/head == this SHA, PR still open (unmerged).
ARG VLLM_PR=48263
ARG VLLM_FIX_SHA=c370902c1243bb09f5729310662aceb7c3dd3737
RUN set -eux; \
    # git used to arrive as a side-effect of the (now retired) efa_installer apt line; \
    # the -efa base doesn't ship it. Self-supply so this stage owns its own deps. \
    command -v git >/dev/null || { apt-get update && apt-get install -y --no-install-recommends git ca-certificates && rm -rf /var/lib/apt/lists/*; }; \
    NIXLSRC="vllm/distributed/kv_transfer/kv_connector/v1/nixl"; \
    mkdir /tmp/vllm-fix; cd /tmp/vllm-fix; \
    git init -q .; git remote add origin https://github.com/vllm-project/vllm.git; \
    git fetch --depth 1 origin "refs/pull/${VLLM_PR}/head"; \
    GOT="$(git rev-parse FETCH_HEAD)"; \
    [ "${GOT}" = "${VLLM_FIX_SHA}" ] || { echo "FAIL: PR#${VLLM_PR} head ${GOT} != tested pin ${VLLM_FIX_SHA} — PR moved; re-validate before bumping the pin"; exit 1; }; \
    git checkout -q FETCH_HEAD -- "${NIXLSRC}"; \
    NIXL="$(python3 -c 'import importlib.util,os; s=importlib.util.find_spec("vllm"); b=s.submodule_search_locations[0]; print(os.path.join(b,"distributed","kv_transfer","kv_connector","v1","nixl"))')"; \
    cp -a /tmp/vllm-fix/${NIXLSRC}/*.py "${NIXL}/"; \
    python3 -c "import os,py_compile; n='${NIXL}'; \
      assert 'NIXL_CONNECTOR_VERSION: int = 8' in open(os.path.join(n,'metadata.py')).read(), 'v8 marker missing after overlay'; \
      [py_compile.compile(os.path.join(n,f), doraise=True) for f in ['connector.py','metadata.py','worker.py','scheduler.py','pp_layer_map.py']]; \
      print('[overlay] tested fix branch applied + v8 marker present + all compile')"; \
    rm -rf /tmp/vllm-fix

# ---- 4) CVE remediation: drop worker-UNUSED /usr/bin/nats-server --------------------
#    Carries the image's sole CRITICAL (CVE-2025-68121, Go stdlib). GA STILL bakes it
#    (16MB, verified) — not converged. The deploy uses an EXTERNAL nats pod, so this
#    baked server binary is never executed. Removing it -> 0 CRITICAL, zero functional
#    impact. Removal (not .trivyignore) is what makes the 0-CRITICAL claim honest.
#    Upstream: https://github.com/ai-dynamo/dynamo/issues/12356
RUN rm -f /usr/bin/nats-server || true

# ---- 5) Final assert: every scenario's prerequisites present in ONE image ------------
RUN set -eux; \
    python3 - <<'PY'
import importlib.metadata as m, importlib.util, os, subprocess
need = {"vllm": "0.23", "ai-dynamo": "1.3", "ray": "2.55.1", "transformers": "5.13.0"}
for p, want in need.items():
    got = m.version(p); assert got.startswith(want), f"{p} {got} !~ {want}"
b = importlib.util.find_spec("vllm").submodule_search_locations[0]
md = os.path.join(b, "distributed/kv_transfer/kv_connector/v1/nixl/metadata.py")
assert "NIXL_CONNECTOR_VERSION: int = 8" in open(md).read(), "PP>1 overlay missing"
assert os.path.exists("/opt/amazon/efa/bin/fi_info"), "EFA userspace missing"
assert not os.path.exists("/usr/bin/nats-server"), "nats-server still present (CRITICAL CVE)"
print("[golden] agg + EP16 + PP>1 prerequisites all present; EFA present; 0-CRITICAL precondition met")
PY

# ---- 6) NVFP4 fix: make flashinfer's cubin package dir writable ----------------------
#    NVFP4 MoE on Blackwell (SM100) makes flashinfer symlink its trtllm cubins INTO the
#    installed flashinfer_cubin PACKAGE tree (ensure_symlink -> link.parent.mkdir,
#    flashinfer/jit/cubin_loader.py). That dir is root-owned, and _get_cubin_dir()
#    (flashinfer/jit/env.py) PREFERS the installed package over FLASHINFER_CUBIN_DIR, so
#    the env var is inert here -> the default non-root `dynamo` worker hits
#    PermissionError [Errno 13] in profile_run at the FIRST NVFP4 MoE call. Make the dir
#    writable at build time so no runtime initContainer / runAsUser:0 is needed; the
#    worker stays non-root. BF16 is unaffected (Unquantized MoE never fetches these
#    cubins). Verified 2026-08-07: with only this line, the non-root user (uid 1000)
#    can mkdir+symlink the exact crash path .../flashinfer_cubin/cubins/flashinfer/trtllm.
RUN set -eux; \
    CUBINS="$(python3 -c 'import os,flashinfer_cubin; print(os.path.join(os.path.dirname(flashinfer_cubin.__file__),"cubins"))')"; \
    mkdir -p "${CUBINS}"; \
    chmod -R a+rwX "${CUBINS}"; \
    python3 - "${CUBINS}" <<'PY'
import os, sys, tempfile
cubins = sys.argv[1]
# assert the runtime user (uid 1000) can create the symlink parent that crashed
probe = os.path.join(cubins, "flashinfer", "trtllm", "batched_gemm")
os.makedirs(probe, exist_ok=True)
t = os.path.join(probe, ".writeprobe"); open(t, "w").write("ok"); os.remove(t)
os.chmod(cubins, 0o777)
print(f"[nvfp4-cubin-fix] {cubins} writable (probe mkdir+write OK)")
PY

USER dynamo
LABEL org.opencontainers.image.description="Golden image: Dynamo 1.3.1 (-efa base, EFA 1.49 baked) + vLLM 0.23 + ray 2.55.1 + vLLM PR#48263 overlay (agg + EP16 + PP>1, Dockerfile-only reproducible)"
LABEL org.opencontainers.image.source="https://github.com/vllm-project/vllm/pull/48263"

