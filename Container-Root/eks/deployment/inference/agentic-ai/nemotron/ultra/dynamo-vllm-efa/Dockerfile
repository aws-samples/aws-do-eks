# Nemotron-550B disagg on Dynamo 1.3.1 (-efa base) + vLLM 0.23 — ONE GOLDEN IMAGE.
#
# Author: Anton Alexander
#
# Covers every scenario: aggregated, EP16 (DP2/TP8), and hybrid-Mamba disagg (NIXL) at
# BOTH PP>1 (step 3) and PP1 (step 3b).
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
# #48263 deliberately does NOT touch the vectorized PP1 fast path, and that path
# overflows its descriptor list on hybrid (Mamba2+FullAttention) models -- PP1 disagg
# returns HTTP 200 while transferring ZERO KV bytes. Step 3b is a surgical, md5-pinned
# edit of the file step 3 fetches, which closes that case. It is a DELTA ON THE OVERLAY:
# the two are retired together.
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

# ---- 3b) FIX: PP1 hybrid-Mamba descriptor-id overflow (follow-up to #48263) ----------
#    SYMPTOM this fixes, on the image built WITHOUT this step: every PP1
#    disaggregated request against a hybrid (Mamba2 + FullAttention) model
#    returns HTTP 200 but moves ZERO KV bytes. The decode worker logs
#      "makeXferReq: local index out of range at index 192 with value 26357617"
#    -> NIXL_ERR_INVALID_PARAM -> the transfer is dropped and decode silently
#    recomputes the whole prefill. Nothing crashes, so it is easy to mistake for
#    "disagg works, EFA is just idle".
#
#    ROOT CAUSE: #48263 deliberately does not touch the vectorized PP1 fast
#    path, and that path is only valid when the dlist it indexes spans every
#    local region at whole-engine counts. For a hybrid model the per-remote
#    handle is built from the producer's registered_layer_names with the SSM-only
#    filter, while _compute_desc_ids derives its SSM region count from the
#    whole-engine (re-advertised, #46407-grown) self.block_len_per_layer. The
#    SSM count therefore overshoots what the dlist actually holds and the first
#    phantom region's desc id lands past the end. The FullAttention half is
#    coincidentally consistent, so ONLY the SSM count diverges -- which is why
#    this reproduces on hybrids and never on pure-attention models.
#    _get_block_descs_ids_for_shard takes BOTH counts from the recorded xfer
#    layout, so its ids are in-bounds by construction and it already asserts
#    max(desc_id) < num_descs. The fix routes hybrids there and leaves the fast
#    path untouched for pure-attention models (the common case).
#
#    MEASURED, same overlay + same patch (a returning request is NOT evidence --
#    only the read-counter delta is):
#      * 550B TP8/PP1 on p6-b200: 0 -> 584 MiB KV per request, 816 makeXferReq
#        errors -> 0, needle recall 4/4.
#      * Hybrid PP1 2-node p5en/H200, prefill and decode on SEPARATE nodes:
#        byte-identical output vs the aggregated control, and the decode node's
#        EFA rdma_read_bytes counter moved by the connector's own byte count.
#      * Reproduced 3x before the fix (desc value 335665 / 423582 / 26357617).
#
#    Applied as a surgical, anchored edit of the file step 3 just fetched -- NOT
#    a second overlay -- so the two must stay in lockstep. Both anchors are
#    asserted unique before the edit and the RESULT is md5-pinned to the exact
#    bytes that produced the measurements above; if #48263's head moves and
#    reflows either anchor, this fails at build time instead of shipping an
#    unmeasured image.
#
#    RETIRE THIS STEP when the fast-path guard lands in the Dynamo-pinned vLLM
#    (or in #48263 itself) -- then the md5 assert below fails loud and you delete
#    3b, exactly as step 1 and the FLASHINFER fence were retired.
ARG NIXL_WORKER_MD5_PRISTINE=7c4871726d013e79ecd1e62249e523c2
ARG NIXL_WORKER_MD5_FIXED=93ef4a4e1aa3b191fcdb3bd194238185
RUN set -eux; \
    NIXL_WORKER_MD5_PRISTINE=7c4871726d013e79ecd1e62249e523c2 \
    NIXL_WORKER_MD5_FIXED=93ef4a4e1aa3b191fcdb3bd194238185 \
    python3 - <<'PY'
import hashlib, importlib.util, os, py_compile

nixl = os.path.join(
    importlib.util.find_spec("vllm").submodule_search_locations[0],
    "distributed", "kv_transfer", "kv_connector", "v1", "nixl")
path = os.path.join(nixl, "worker.py")
src = open(path).read()

want_pristine = os.environ["NIXL_WORKER_MD5_PRISTINE"]
want_fixed = os.environ["NIXL_WORKER_MD5_FIXED"]
got = hashlib.md5(src.encode()).hexdigest()
assert got == want_pristine, (
    f"step 3 produced worker.py md5 {got}, expected {want_pristine}. PR#48263's "
    "head moved -- re-validate the fix against the new revision before bumping "
    "VLLM_FIX_SHA and the md5 pins here.")

# Hunk 1: refuse the whole-engine layout for hybrids instead of computing
# plausible-but-out-of-range ids.
A1_OLD = '''\
        """Compute NIXL descriptor IDs for given block IDs."""
        num_fa_regions = self.num_regions
'''
A1_NEW = '''\
        """Compute NIXL descriptor IDs for given block IDs."""
        # P6' FIX-3 invariant: this whole-engine layout is only valid when the
        # dlist being indexed spans every local region at whole-engine counts.
        # A hybrid model's per-remote handle is built from the producer's
        # registered_layer_names with the FIX-2 SSM-only filter, so the counts
        # below (self.num_regions / len(self.block_len_per_layer), both grown by
        # the #46407 re-advertise) overshoot its mamba section. Hybrid transfers
        # are routed to _get_block_descs_ids_for_shard in _read_blocks; assert
        # here so a future caller gets a loud failure instead of an
        # out-of-range desc id (or, worse, in-bounds ids at wrong offsets).
        assert not self._has_mamba, (
            "_compute_desc_ids is whole-engine-layout only; hybrid/HMA models "
            "must use _get_block_descs_ids_for_shard (P6' FIX-3)"
        )
        num_fa_regions = self.num_regions
'''

# Hunk 2: route hybrid/HMA transfers off the fast path.
A2_OLD = '''\
        # proven P1->D1 / P2->D1 topologies (consumer PP==1, no BUG-10 filtering).
        _consumer_single_stage = (
            self.vllm_config.parallel_config.pipeline_parallel_size == 1
        )
        if self._remote_pp_size[dst_engine_id] == 1 and _consumer_single_stage:
'''
A2_NEW = '''\
        # proven P1->D1 / P2->D1 topologies (consumer PP==1, no BUG-10 filtering).
        #
        # P6' FIX-3 (hybrid P1->D1 desc-id overflow, measured 3x: cgk H200
        # 2026-07-08 value=335665, cgk H200 2026-07-26 value=423582, B200
        # 550B 2026-08-14 value=26357617): the "fast path preserved for the
        # proven P1->D1" claim above does NOT hold once the model is hybrid AND
        # the producer re-advertises dedup'd members (P6' FIX-2 / vLLM #46407).
        # Reason: the local handle this xfer indexes is NOT the whole-engine
        # init-time dlist -- _read_blocks receives
        # src_xfer_handles_by_remote[(engine, pp_rank, remote_block_size)],
        # which register_local_xfer_handler built from the producer's
        # registered_layer_names, applying the FIX-2 SSM-only filter to the
        # mamba section (len(_ssm_layer_names(registered)) * 4 desc-groups).
        # _compute_desc_ids instead derives its SSM region count from the
        # whole-engine, FIX-2-GROWN self.block_len_per_layer (len * 4), so it
        # addresses more SSM regions than that dlist contains and the first
        # phantom region's desc id lands past the end:
        #   bad_id = num_fa_descs + n_ssm_regions_registered * logical + block
        # nixl then correctly rejects the prepped xfer with
        # "makeXferReq: local index out of range" -> NIXL_ERR_INVALID_PARAM ->
        # 0 KV bytes on every request (decode silently recomputes prefill).
        # The FA half is coincidentally consistent (both sides are 2x the
        # registered region count), so ONLY the SSM count diverges.
        # _get_block_descs_ids_for_shard has no such divergence: it takes BOTH
        # counts from _xfer_desc_layouts[(engine, pp_rank, side)] -- the layout
        # recorded from the same registered_layer_names the dlist was built
        # from -- so ids are in-bounds by construction, it skips SSM-group
        # regions in the FA loop instead of reading Mamba bytes at FA stride,
        # and it asserts max(desc_id) < num_descs before returning. That path is
        # also the one measured moving correct KV on this same overlay+model
        # (P2->D1, +1.53 GB/req, 2026-08-12). So: keep the vectorized fast path
        # for pure-attention models (unaffected, and it stays the common case),
        # and route every hybrid/HMA transfer through the layout-derived path.
        _consumer_single_stage = (
            self.vllm_config.parallel_config.pipeline_parallel_size == 1
        )
        if (
            self._remote_pp_size[dst_engine_id] == 1
            and _consumer_single_stage
            and not self._has_mamba
        ):
'''

for name, old in (("A1", A1_OLD), ("A2", A2_OLD)):
    n = src.count(old)
    assert n == 1, f"anchor {name} found {n}x (expected 1) -- upstream reflowed it"

src = src.replace(A1_OLD, A1_NEW, 1).replace(A2_OLD, A2_NEW, 1)

got = hashlib.md5(src.encode()).hexdigest()
assert got == want_fixed, (
    f"patched worker.py md5 {got} != measured {want_fixed} -- the image would "
    "differ from the one that was gated; refusing to build.")

open(path, "w").write(src)
py_compile.compile(path, doraise=True)
assert "whole-engine-layout only" in open(path).read()  # unique to this fix
print(f"[fix-3] PP1 hybrid fast-path bypass applied; worker.py md5 {got} "
      "(byte-identical to the gated image)")
PY

# ---- 4) CVE remediation: drop worker-UNUSED /usr/bin/nats-server --------------------
#    Carries the image's sole CRITICAL (CVE-2025-68121, Go stdlib). GA STILL bakes it
#    (16MB, verified) — not converged. The deploy uses an EXTERNAL nats pod, so this
#    baked server binary is never executed. Removing it -> 0 CRITICAL, zero functional
#    impact. Removal (not .trivyignore) is what makes the 0-CRITICAL claim honest.
#    Upstream: https://github.com/ai-dynamo/dynamo/issues/12356
RUN rm -f /usr/bin/nats-server || true

# ---- 5) Final assert: every scenario's prerequisites present in ONE image ------------
RUN set -eux; \
    NIXL_WORKER_MD5_FIXED=93ef4a4e1aa3b191fcdb3bd194238185 \
    python3 - <<'PY'
import hashlib, importlib.metadata as m, importlib.util, os, subprocess
need = {"vllm": "0.23", "ai-dynamo": "1.3", "ray": "2.55.1", "transformers": "5.13.0"}
for p, want in need.items():
    got = m.version(p); assert got.startswith(want), f"{p} {got} !~ {want}"
b = importlib.util.find_spec("vllm").submodule_search_locations[0]
md = os.path.join(b, "distributed/kv_transfer/kv_connector/v1/nixl/metadata.py")
assert "NIXL_CONNECTOR_VERSION: int = 8" in open(md).read(), "PP>1 overlay missing"
w = os.path.join(b, "distributed/kv_transfer/kv_connector/v1/nixl/worker.py")
# NOTE: do NOT assert on "and not self._has_mamba" alone -- that string already
# occurs twice in the UNPATCHED file (a PP filter and a use_mla guard), so its
# presence proves nothing. Pin the md5 step 3b produced: exact, and it is the
# revision the measurements in 3b were taken on.
got = hashlib.md5(open(w, "rb").read()).hexdigest()
assert got == os.environ["NIXL_WORKER_MD5_FIXED"], (
    f"worker.py md5 {got} is not the FIX-3 revision step 3b produces "
    f"({os.environ['NIXL_WORKER_MD5_FIXED']}); PP1 hybrid disagg would return 200 "
    "and move 0 KV bytes")
assert os.path.exists("/opt/amazon/efa/bin/fi_info"), "EFA userspace missing"
assert not os.path.exists("/usr/bin/nats-server"), "nats-server still present (CRITICAL CVE)"
print("[golden] agg + EP16 + PP>1 + PP1-hybrid prerequisites all present; EFA present; "
      "0-CRITICAL precondition met")
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
#    cubins).
#
#    IMPORTANT (fixes a regression in the first cut of this step): do NOT pre-create
#    the cubins/flashinfer/trtllm/batched_gemm subtree here. A build-time probe that
#    did `os.makedirs(...batched_gemm)` left those subdirs ROOT-OWNED 0755, and a
#    subsequent `chmod cubins 0777` only re-permed the TOP dir — so at runtime the
#    non-root worker still hit PermissionError[13] symlinking INTO the root-owned
#    batched_gemm. The correct fix is chmod -R the cubins dir and leave it EMPTY: the
#    worker then creates the whole flashinfer/trtllm/... subtree itself (worker-owned).
#    Verified as uid 1000: symlink into batched_gemm SUCCEEDS with this recipe, FAILS
#    if the subtree is pre-created. Keep this a single chmod -R with no makedirs probe.
RUN set -eux; \
    CUBINS="$(python3 -c 'import os,flashinfer_cubin; print(os.path.join(os.path.dirname(flashinfer_cubin.__file__),"cubins"))')"; \
    mkdir -p "${CUBINS}"; \
    chmod -R a+rwX "${CUBINS}"; \
    test -w "${CUBINS}"; \
    echo "[nvfp4-cubin-fix] ${CUBINS} made writable (chmod -R a+rwX; subtree left empty for the worker to own)"

USER dynamo
LABEL org.opencontainers.image.description="Golden image: Dynamo 1.3.1 (-efa base, EFA 1.49 baked) + vLLM 0.23 + ray 2.55.1 + vLLM PR#48263 overlay + PP1 hybrid-Mamba descriptor-id fix (agg + EP16 + PP>1 + PP1 disagg, Dockerfile-only reproducible)"
LABEL org.opencontainers.image.source="https://github.com/vllm-project/vllm/pull/48263"

