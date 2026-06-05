# ================================================================================================
# Nemotron-3 disagg image on NVIDIA's official -efa base (current: 1.2.0-efa = vLLM 0.20.1).
# Author: Anton Alexander
# Only addition: 5 disagg anchor-patches (vLLM PR#42522 folded into PR#43935), rebased to 0.20.1.
# No pip vllm pin (track NVIDIA's base). No AWS EFA overlay (NVIDIA ships EFA + NIXL LIBFABRIC).
# When vLLM #43935 merges + ships in this -efa image -> ENABLE_DISAGG_PATCHES=0 (zero patches).
# Patches verified --fuzz=0 against vLLM 0.19.0 AND 0.20.1; rebase + synthetic-config test in
# apply-disagg-patches.sh. Override base for an older tag with --build-arg VLLM_EFA_IMAGE=...
# ================================================================================================

ARG VLLM_EFA_IMAGE=nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.2.0-efa
FROM ${VLLM_EFA_IMAGE}
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]
USER root
ARG ENABLE_DISAGG_PATCHES=1
# Record the base vLLM version (informational; patches apply --fuzz=0 across 0.19.0/0.20.1).
RUN python3 -c "import vllm; print('[base] vllm', vllm.__version__)"
COPY patches/pr-disagg-*.patch /tmp/dp/
COPY apply-disagg-patches.sh /tmp/apply-disagg-patches.sh
RUN if [ "${ENABLE_DISAGG_PATCHES}" = "1" ]; then bash /tmp/apply-disagg-patches.sh; else echo "[disagg] skipped"; fi && rm -rf /tmp/dp /tmp/apply-disagg-patches.sh

# -----------------------------------------------------------------------------
# CVE hardening - remove non-runtime Go binaries the WORKER/FRONTEND never runs.
# The official -efa base vendors etcd/etcdctl/etcdutl (~57MB) and nats-server
# (~16MB). In the blog deployment, etcd + NATS run as their OWN dynamo-platform
# pods; the worker/frontend connect via ETCD_ENDPOINTS / NATS_SERVER env (no
# exec of these binaries - verified: zero references in the dynamo python pkg).
# Gated + reversible: build --build-arg STRIP_UNUSED_SERVERS=0 to keep them
# (e.g. an all-in-one single-pod dev image that embeds etcd/NATS locally).
ARG STRIP_UNUSED_SERVERS=1
RUN if [ "${STRIP_UNUSED_SERVERS}" = "1" ]; then \
        rm -rf /usr/local/bin/etcd /usr/local/bin/etcdctl /usr/local/bin/etcdutl \
               /usr/bin/etcd /usr/bin/etcdctl /usr/bin/etcdutl \
               /usr/bin/nats-server /usr/local/bin/nats-server && \
        echo "[harden] removed unused etcd/* + nats-server (worker connects via env endpoints)"; \
    else \
        echo "[harden] STRIP_UNUSED_SERVERS=0 - keeping embedded servers (all-in-one image)"; \
    fi
# git-lfs 3.4.1 (compiled with go1.22.2) is the SOLE remaining source of the
# image's CRITICAL CVEs: CVE-2024-24790 (go <1.22.4 netip) and CVE-2025-68121
# (go <1.24.13). No published git-lfs release is yet built on go>=1.24.13, so an
# upgrade can't clear CVE-2025-68121 - removal is the genuine fix, not a
# .trivyignore suppression. The serving path does NOT use the git-lfs binary:
# huggingface_hub/lfs.py is a pure-Python HTTPS LFS implementation and
# snapshot_download/hf_hub_download fetch over HTTP; the binary is only invoked
# by `git clone` of an LFS repo, which is not our weight-loading flow (weights
# are FSx/HF-cache mounted). Independently gated + reversible: build
# --build-arg STRIP_GIT_LFS=0 to keep it (e.g. a build that git-clones weights).
ARG STRIP_GIT_LFS=1
RUN if [ "${STRIP_GIT_LFS}" = "1" ]; then \
        git lfs uninstall --system >/dev/null 2>&1 || true; \
        rm -f /usr/bin/git-lfs /usr/local/bin/git-lfs && \
        echo "[harden] removed git-lfs binary (serving uses huggingface_hub pure-python LFS over HTTPS)"; \
    else \
        echo "[harden] STRIP_GIT_LFS=0 — keeping git-lfs (git-clone weight-loading flow)"; \
    fi

USER dynamo
