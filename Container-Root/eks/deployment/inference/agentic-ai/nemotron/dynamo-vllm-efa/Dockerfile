# Nemotron family on Dynamo 1.5.0 (-efa base) + vLLM 0.28.0 + Ray + patches — ONE recipe for ../super (3.5 Super VL 120B-A12B)
# and ../ultra (3 Ultra 550B-A55B).
#
# Author: Anton Alexander
#
# Consolidates (2026-10-20) the three recipes the two trees used to carry; the superseded files stay in the folders' git history
# (each sibling folder keeps a README naming the commit that holds them):
#   ../ultra/dynamo-vllm-efa/Dockerfile      vllm-runtime:1.4.0-efa (vLLM 0.26) + the 0.26-era NIXL PP>1 pull-path patches + ray
#                                            + CVE removals -> the PUBLIC image dynamo-vllm-efa:1.4.0-patched that ../ultra's .env
#                                            still defaults to and whose RESULTS rows were measured.
#   ../super/dynamo-vllm-efa/Dockerfile      vllm-runtime:1.5.0-efa golden image: base asserts + CVE removals, no ray, no patches.
#   ../super/dynamo-vllm-efa/Dockerfile.ray  the same base + ray + the VL-wrapper SupportsPP patch + opt-in NIXL PP>1 backport
#                                            + opt-in EPD encode-worker patch. THIS file is Dockerfile.ray generalized to the family.
#
# Build (the three builds below reproduce the three measured images; the pipeline builds the last one, see buildspec.yaml):
#   docker build -t dynamo-vllm-efa:1.5.0-ray .                                                            # ray + SupportsPP only
#   docker build --build-arg NIXL_PP_PATCH=1 -t dynamo-vllm-efa:1.5.0-ray-nixlpp .                        # + PP>1 disagg (both roles!)
#   docker build --build-arg NIXL_PP_PATCH=1 --build-arg DYNAMO_EPD_NEMOTRON_PATCH=1 -t dynamo-vllm-efa:1.5.0-patched .   # + disagg/epd
#   DOCKER_BUILD_ARGS="--build-arg NIXL_PP_PATCH=1 --build-arg DYNAMO_EPD_NEMOTRON_PATCH=1" ./build-sbom-scan.sh   # + SBOM + CVE gate
#
# MEASURED (node-recorded image digests; ../super/test/RESULTS.md footnotes). Every layer below was exercised on these builds:
#   no build args                   sha256:bb36e7449c2f…  every non-PP Super cell on the p5e EKS Auto Mode cluster, 2026-10-19/20
#                                                         (BF16 + NVFP4 agg/deployment, lws, lws-ep, dgd, dgd-v1beta1, dgd-grove,
#                                                         dgd-grove-ep; disagg/deployment, lws-ep, dgd, dgd-v1beta1, dgd-grove,
#                                                         dgd-grove-ep) and the CGK p5en Dynamo 1.5.1 spot-check rows.
#   NIXL_PP_PATCH=1                 sha256:43561d30cf85…  every PP>1 disagg cell: p5e footnotes 56-61 (an earlier cut of the same patch,
#                                                         947ff0caa1b0, carried 56/57), CGK 102-104, 106, 108, 109 — temperature-0 output
#                                                         byte-identical to PP1, per-stage KV over EFA at byte parity.
#   + DYNAMO_EPD_NEMOTRON_PATCH=1   sha256:8f66005fa237…  the two disagg/epd cells, CGK footnotes 101 / 105.
# NOT MEASURED — stated gates, not results:
#   - Nemotron-3 Ultra 550B has NOT been served on ANY 1.5.0 image. Its measured rows are on 1.4.0-patched (vLLM 0.26); its .env
#     --moe-backend flashinfer_cutlass pin and 4096/0.97 engine knobs encode vLLM 0.26 measurements (vllm#53472) unmeasured on 0.28.
#     The 0.26 PP>1 patch cannot apply to the rewritten 0.28.0 nixl package; step 3b is its 0.28.0 successor (same intent).
#   - This consolidated build has not been run on a GPU cell: the lane that cut it was GPU-free (docker build + syft SBOM + trivy
#     CVE gate + template renders + server-side dry-runs). The first cell on it is a measurement to take, not a result to quote.
#   - The 2026-10-21 CVE layer (steps 4h-4k: certifi + pillow 13 bumps, uv and cosmos-guardrail/nltk removed) is likewise measured
#     GPU-free only (throwaway-container imports, pip check deltas, the Super VL image processor on CPU).
#
#   patch 1 (SupportsPP, always on): NemotronH_Nano_VL_V2 (resolved from the NemotronH_Super_Omni_Reasoning_V3 --hf-overrides alias)
#            wraps NemotronHForCausalLM, which implements SupportsPP, but the VL wrapper does not inherit it and lacks
#            make_empty_intermediate_tensors(); vLLM 0.28.0 refuses PP>1 for it at verify_with_parallel_config and again at the
#            profile_run (MEASURED 2026-10-18, 4x p5e.48xlarge). The patch adds both. It edits only nano_nemotron_vl.py, a module the
#            text-only 550B model never loads, so it is a no-op for ../ultra and required for every ../super PP>1 shape.
#   patch 2 (OPTIONAL, NIXL_PP_PATCH=1): NIXL pull-path pipeline parallelism for PP>1 prefill AND decode of a hybrid-Mamba model
#            (disagg/lws-2pp, lws-pp2, dgd-grove-pp2 in BOTH trees): the backport of the open upstream PR vllm-project/vllm#53360 onto
#            vLLM 0.28.0 (patches/0002-*.diff). Stock 0.28.0 refuses every PP>1 NIXL worker of a Mamba hybrid at init. Off by default
#            (unmerged upstream change); see step 3b.
#   patch 3 (OPTIONAL, DYNAMO_EPD_NEMOTRON_PATCH=1): dynamo 1.5.0's standalone vision ENCODE worker (../super disagg/epd) knows only the
#            LLaVA and Qwen-VL families and rejects this checkpoint after full-loading it (patches/0003-*.diff adds the NemotronH Omni /
#            Nano-VL family; patches/0004-*.diff fixes the PD side's image_embeds ingestion). Off by default (not upstream); see step 3c.
#
# Ray 2.55.1 is the PP2-proven pin from both trees (ultra's 1.4.0-patched image and super's Dockerfile.ray; import-verified below).
#
# ---------------------------------------------------------------------------------------
# BASE: 1.5.0-efa. Verified contents (docker image inspect + docker run, 2026-10-06) — this drove which golden layers survived
# from the ultra recipe and which were retired. Golden-rule: do NOT assume a newer base fixes a layer — measure it.
#
#     vllm 0.28.0 | ai-dynamo 1.5.0 | nixl 1.3.2 (libplugin_LIBFABRIC.so present)
#     transformers 5.14.1 (>= 5.13 NemotronH inspection requirement: assert, no pin)
#     flashinfer-jit-cache 0.6.16.post3+cu130 == flashinfer-python 0.6.16.post3 -> skew fence stays retired (matched pair)
#     EFA installer 1.50.0 BAKED (+ /opt/amazon/ofi-nccl) -> assert-only
#     runai-model-streamer 0.16.1 present -> LOAD_FORMAT=runai_streamer (both trees' .env default) valid
#     registry: NemotronH_Super_Omni_Reasoning_V3 REGISTERED, bare NemotronH_Omni_Reasoning_V3 NOT (first registered in vLLM
#       v0.29.0) -> ../super's --hf-overrides alias is REQUIRED on this base; NemotronHForCausalLM (../ultra) registered
#     nemotron_h_mtp in MTPModelTypes -> ../super's SPEC_DECODE toggle structurally valid
#     ray ABSENT (never shipped by any NGC base)   -> install layer KEPT (step 2)
#     nats-server STILL baked (17 MB)            -> CVE removal layer KEPT
#     etcd/etcdctl/etcdutl STILL baked (61 MB)   -> CVE removal layer KEPT
#     apt launchpadlib chain STILL baked (python3-cryptography 41.0.7 et al) -> KEPT
#     mooncake-transfer-engine ABSENT under that name, BUT the 1.5.0 base ships the SAME optional Mooncake KV connector as
#       mooncake-transfer-engine-cuda13 0.3.13.post1 (measured 2026-10-20 by the CVE gate: its bundled Go libetcd_wrapper.so
#       carries 19 HIGH) -> the super recipe's "converged" assert on the old name passed vacuously; ultra's 4c removal layer
#       is RESTORED as step 4e and the assert covers both names
#     lmcache 0.5.4 PRESENT (optional LMCache KV connector, unused by every template; CRITICAL CVE-2026-105192; the fixed
#       0.5.6 would pull grpcio 1.78 + nvidia-nccl-cu13 2.29.7 = a NCCL change) -> REMOVED in 4e, not bumped
#     pyjwt 2.13.0 (CRITICAL CVE-2026-102268 + 5 HIGH; required only by mcp, msal), urllib3 2.7.0 (2 HIGH), aiohttp 3.14.3
#       (2 HIGH; ray also vendors a 3.13.5 copy under ray/_private/runtime_env/agent/thirdparty_files that pip cannot reach),
#       openssl/libssl3t64 3.0.13-0ubuntu3.15 (1 HIGH, Ubuntu fix 3.0.13-0ubuntu3.16 available) -> measured bumps in 4f/4g
#     2026-10-21, first pipeline report (3 CRITICAL / 12 HIGH with the 2026-10-21T01:19Z trivy DB on the UNCHANGED package set):
#       certifi 2026.7.22 (CRITICAL GHSA-6q48-6c7w-9gw2), pillow 12.3.0 (CRITICAL CVE-2026-112403 + 6 HIGH), uv 0.12.5 (CRITICAL
#       GHSA-hq85-5cpj-mr62; a 2nd 0.12.0 copy under /opt/uv), one more HIGH on ray's vendored aiohttp -> measured bump / bump /
#       removal in 4h-4j; nltk's only carrier cosmos-guardrail removed in 4k
#     /opt/uv/cache ABSENT                        -> ultra's 4d layer RETIRED (assert)
#     venv cryptography 50.0.0                    -> ultra's 4f layer RETIRED (assert)
#     flashinfer_cubin/cubins WRITABLE by uid 1000 (gid 0, mode 775 group-write; mkdir test PASSED) -> ultra's chmod layer RETIRED (assert)
#     default USER dynamo (uid 1000, gid 0); NO /opt/dynamo/venv (system python)
#   The base bakes the EFA bits but NOT the env contract (FI_PROVIDER, NCCL_NET_PLUGIN, ...): both trees' templates carry it per
#   container, so this image deliberately bakes no FI_*/NCCL_* ENV (ultra's 1.4.0 recipe did; its templates set the same values).
# ---------------------------------------------------------------------------------------
ARG BASE=nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.5.0-efa
FROM ${BASE}

USER root
SHELL ["/bin/bash", "-c"]

# ---- 0) Assert the base is what we think it is ---------------------------------------
#    Every layer verdict below was measured on vllm 0.28.0 / ai-dynamo 1.5.0. If a future
#    BASE arg moves either, the measurements are void: fail at build, not at serve.
#    The model-specific asserts (Super Omni alias + MTP method for ../super, NemotronHForCausalLM
#    for ../ultra) make this image the FAMILY's golden image rather than a generic runtime.
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
m.version("runai-model-streamer")  # LOAD_FORMAT=runai_streamer in both trees' .env
from vllm.model_executor.models.registry import ModelRegistry
archs = ModelRegistry.get_supported_archs()
assert "NemotronH_Super_Omni_Reasoning_V3" in archs, \
    "Super Omni arch alias missing from the vLLM registry - ../super's --hf-overrides cannot work"
assert "NemotronHForCausalLM" in archs, "NemotronHForCausalLM missing from the vLLM registry - ../ultra cannot load"
if "NemotronH_Omni_Reasoning_V3" in archs:
    print("[base] NOTE: bare NemotronH_Omni_Reasoning_V3 is registered (vLLM >= 0.29 era base);"
          " ../super's --hf-overrides alias is now optional")
import typing
from vllm.config.speculative import MTPModelTypes
assert "nemotron_h_mtp" in typing.get_args(MTPModelTypes), \
    "nemotron_h_mtp missing from MTPModelTypes - ../super's SPEC_DECODE toggle would be invalid"
print(f"[base] vllm={v} ai-dynamo={d} transformers={m.version('transformers')} "
      f"flashinfer={fi_py} super-omni-arch+mtp OK, NemotronHForCausalLM OK")
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

# ---- 2) Ray for the multi-node PP shapes (agg/lws, disagg/lws-2pp, disagg/lws-pp2 in both trees) ----
#    ray: PP>1 agg needs `--distributed-executor-backend ray`. ABSENT from every NGC base.
#    2.55.1 is the PP2-proven pin (ultra 1.4.0-patched: 550B PP2 on B200; super: p5e PP2 cells). Import-verified below.
RUN set -eux; \
    pip install --no-cache-dir "ray[default]==2.55.1"; \
    python3 - <<'PY'
import importlib.metadata as m
assert m.version("ray") == "2.55.1", m.version("ray")
assert m.version("vllm").startswith("0.28"), "ray install drifted vllm off 0.28.x"
import ray  # import, not just metadata
print("[deps] ray=2.55.1 installed, vllm intact")
PY

# ---- 3) VL wrapper PP patch: NemotronH_Nano_VL_V2 SupportsPP + make_empty_intermediate_tensors ----
#    MEASURED (2026-10-18, 4x p5e.48xlarge EKS Auto Mode): agg/lws with PP2 + Ray crashes at verify_with_parallel_config
#    (SupportsPP missing) and then at the profile_run (make_empty_intermediate_tensors missing). The patch:
#      a) Adds SupportsPP to the imports and class bases.
#      b) Adds make_empty_intermediate_tensors() returning {"hidden_states", "residual"} matching what
#         NemotronHModel.forward() yields on intermediate PP ranks.
#    ../ultra never loads this module (text-only NemotronHForCausalLM) - a no-op there.
COPY patches/apply_pp_patch.py /opt/vllm-patches/apply_pp_patch.py
RUN python3 /opt/vllm-patches/apply_pp_patch.py

# ---- 3b) OPTIONAL: NIXL pull-path pipeline-parallel (PP>1 prefill AND decode) for hybrid-Mamba, vLLM 0.28.0 ----
#    Stock vLLM 0.28.0 raises at worker init for every PP>1 NIXL worker of a Mamba hybrid
#    (base_worker.py: "does not support pipeline_parallel_size > 1 with hybrid KV cache layouts (HMA)"),
#    which blocks disagg/lws-2pp, disagg/lws-pp2 and disagg/dgd-grove-pp2 in BOTH trees (../super/test/RESULTS.md footnotes 26/42).
#    patches/0002-nixl-pull-path-pipeline-parallel-0.28.0.vllm.diff is the backport of the open upstream PR
#    vllm-project/vllm#53360 (head d20b060) onto the 0.28.0 nixl package: per-stage handshake and reads, pooled-region
#    (HMA) member routing, symmetric PP consumers. It bumps the connector wire version 7 -> 10, so BOTH roles of a
#    disagg pair must run the same build (a stock peer fails the handshake loudly). For ../ultra this is the 0.28.0
#    successor of its 0.26-era patches/0001 (same three intents); it is UNMEASURED on the 550B model.
#    Opt-in (--build-arg NIXL_PP_PATCH=1): an unmerged upstream change stays out of the default image; the buildspec turns it ON.
#    Strict: --dry-run --fuzz=0 first, so a base drift fails the build and not a GPU node at serve time; the verifier
#    then proves the patched package imports and carries the markers.
ARG NIXL_PP_PATCH=0
COPY patches/0002-nixl-pull-path-pipeline-parallel-0.28.0.vllm.diff patches/verify_nixl_pp_patch.py /opt/vllm-patches/
RUN set -eux; \
    if [ "${NIXL_PP_PATCH}" = "1" ]; then \
      SITE="$(python3 -c 'import importlib.util; print(importlib.util.find_spec("vllm").submodule_search_locations[0].rsplit("/vllm",1)[0])')"; \
      cd "${SITE}"; \
      patch -p1 --dry-run --fuzz=0 --forward < /opt/vllm-patches/0002-nixl-pull-path-pipeline-parallel-0.28.0.vllm.diff; \
      patch -p1 --fuzz=0 --forward < /opt/vllm-patches/0002-nixl-pull-path-pipeline-parallel-0.28.0.vllm.diff; \
      python3 /opt/vllm-patches/verify_nixl_pp_patch.py; \
    else echo "[nixl-pp] NIXL_PP_PATCH=0: stock NIXL connector (PP>1 disagg of hybrid-Mamba models stays unsupported)"; fi

# ---- 3c) OPTIONAL: dynamo encode-worker support for the NemotronH Omni / Nano-VL family (../super disagg/epd) ----
#    dynamo 1.5.0's standalone encode worker (`python -m dynamo.vllm --disaggregation-mode encode`) knows only the
#    LLaVA and Qwen-VL families: multimodal_utils/encode_utils.py get_encoder_components raises
#    NotImplementedError("Model not supported") for this checkpoint, and only AFTER multimodal_utils/model.py
#    full-loaded it with AutoModel.from_pretrained (~249 GB for BF16) - ../super/test/RESULTS.md footnotes 19, 42.
#    patches/0003-dynamo-encode-worker-nemotron-h-omni-1.5.0.dynamo.diff registers the family and:
#      - loads the vision side (RADIO tower + pixel shuffle + mlp1) through vLLM's own encoder-only engine
#        (--mm-encoder-only, the recipe dynamo already uses for Qwen-VL), so the encode worker runs the same
#        RadioModel/mlp1 code and weights the PD worker would run in-process; the worker's --hf-overrides
#        (architecture alias on vLLM 0.28.x) is forwarded to it;
#      - produces one (num_tokens, hidden) embedding per image through the model's extract_feature_dynamic
#        (dynamic-resolution tiler, token count varies per image);
#      - makes the PD side (--enable-mm-embeds) ingest them as the per-image 2-D embeddings vLLM's
#        NemotronH_Nano_VL_V2 already accepts (image_embeds), owning copies before the NIXL buffer is released.
#    The PD side also needs patches/0004-nano-nemotron-vl-image-embeds-num-patches-0.28.0.vllm.diff: vLLM 0.28.0's
#    NanoNemotronVL processor builds `image_num_patches = [None] * n` for pre-computed image_embeds and then runs
#    int(None) in get_image_replacement (TypeError -> HTTP 500 on every image request; MEASURED 2026-10-20; still
#    present on vLLM main) - a one-line guard keeps the None that get_image_repl() already accepts; and the model's
#    _parse_and_validate_image_input tests the embeds tensor for truthiness (`if image_embeds := ...:`) which raises
#    "Boolean value of Tensor with more than one value is ambiguous" and kills the EngineCore (MEASURED 2026-10-20) -
#    the second hunk tests for presence instead. Inert for ../ultra (no epd template, text-only model).
#    Opt-in (--build-arg DYNAMO_EPD_NEMOTRON_PATCH=1): out-of-tree dynamo/vLLM changes stay out of the default image;
#    the buildspec turns it ON. Strict apply (--dry-run --fuzz=0 --forward) + patches/verify_dynamo_epd_patch.py, as in 3b.
ARG DYNAMO_EPD_NEMOTRON_PATCH=0
COPY patches/0003-dynamo-encode-worker-nemotron-h-omni-1.5.0.dynamo.diff patches/0004-nano-nemotron-vl-image-embeds-num-patches-0.28.0.vllm.diff patches/verify_dynamo_epd_patch.py /opt/vllm-patches/
RUN set -eux; \
    if [ "${DYNAMO_EPD_NEMOTRON_PATCH}" = "1" ]; then \
      SITE="$(python3 -c 'import os, dynamo.vllm; print(os.path.dirname(os.path.dirname(os.path.dirname(dynamo.vllm.__file__))))')"; \
      cd "${SITE}"; \
      for P in 0003-dynamo-encode-worker-nemotron-h-omni-1.5.0.dynamo.diff 0004-nano-nemotron-vl-image-embeds-num-patches-0.28.0.vllm.diff; do \
        patch -p1 --dry-run --fuzz=0 --forward < "/opt/vllm-patches/${P}"; \
        patch -p1 --fuzz=0 --forward < "/opt/vllm-patches/${P}"; \
      done; \
      python3 /opt/vllm-patches/verify_dynamo_epd_patch.py; \
    else echo "[dynamo-epd] DYNAMO_EPD_NEMOTRON_PATCH=0: stock encode worker (disagg/epd of the NemotronH Omni family stays unsupported)"; fi

# ---- 4) CVE remediation: drop worker-UNUSED binaries ----------------------------------
#    Same principle as the 1.4.0 ultra recipe: REMOVE (not .trivyignore) anything the workers never
#    execute, so the CVE gate stays honest. Presence of each carrier was MEASURED on this base
#    2026-10-06; the retired ultra layers (mooncake, uv cache, venv cryptography, cubin chmod) are
#    asserted-converged in step 5 instead of blindly re-applied.
# 4a) nats-server (17 MB): still baked; the deploy uses an EXTERNAL nats pod.
#     Upstream: https://github.com/ai-dynamo/dynamo/issues/12356
RUN rm -f /usr/bin/nats-server || true
# 4b) etcd server binaries (etcd/etcdctl/etcdutl, 61 MB): worker-unused — every template points at an EXTERNAL etcd.
RUN rm -rf /usr/local/bin/etcd
# 4c) apt launchpadlib chain (runtime-unused `add-apt-repository` support; the runtime python resolves /usr/local first,
#     so these were shadowed anyway). Measured present 2026-10-06: python3-cryptography 41.0.7, python3-jwt 2.7.0,
#     python3-httplib2 0.20.4, python3-launchpadlib, python3-lazr.restfulclient, python3-oauthlib, software-properties-common.
RUN apt-get remove -y --purge \
      python3-launchpadlib python3-lazr.restfulclient python3-oauthlib \
      python3-jwt python3-httplib2 python3-cryptography \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*
# 4d) ray_dist.jar (Ray's Java driver): our templates drive ray from Python only (`--distributed-executor-backend ray`);
#     the jar carries Java-ecosystem CVEs. `import ray` + the step-5 assert stay green without it.
RUN rm -f /usr/local/lib/python3.12/dist-packages/ray/jars/ray_dist.jar
# 4e) Optional KV connectors no template uses (every disagg template here moves KV through NixlConnector LIBFABRIC;
#     vLLM imports both only lazily, inside its MooncakeConnector / LMCacheConnectorV1 classes; `pip show` lists no requirer):
#     - lmcache 0.5.4: CRITICAL CVE-2026-105192. The fixed release 0.5.6 would pull grpcio 1.78.0 + nvidia-nccl-cu13 2.29.7
#       (a NCCL change under torch) - so REMOVE, do not bump.
#     - mooncake-transfer-engine-cuda13 0.3.13.post1: the 1.5.0 base ships Mooncake under this cu13 wheel name; its bundled
#       mooncake/libetcd_wrapper.so (Go stdlib 1.25.10, x/net v0.55.0, x/text v0.37.0, grpc v1.82.1) carries 19 HIGH -
#       the same carrier ultra's 1.4.0 recipe removed as `mooncake-transfer-engine`. Restore path if a Mooncake scenario ever
#       lands here: `pip install mooncake-transfer-engine-cuda13` (and re-run the CVE gate).
#     MEASURED 2026-10-20 (throwaway container of this image): `pip check` delta vs stock empty; vllm, ray, dynamo.vllm.main,
#     the KV-connector factory, the NIXL connector + base/pull workers and the Nemotron model classes all import afterwards.
RUN pip uninstall -y lmcache mooncake-transfer-engine-cuda13
# 4f) Measured pip bumps - pure-Python libraries, no vllm/torch/ray/nixl pin touched (asserted in step 5):
#     pyjwt 2.13.0 -> 2.14.0 (CRITICAL CVE-2026-102268 + HIGH CVE-2026-102266/-102267/-102271/-102272/-102273; required
#     only by mcp and msal), urllib3 2.7.0 -> 2.8.0 (HIGH CVE-2026-97687/-97689), aiohttp 3.14.3 -> 3.14.4 (HIGH
#     CVE-2026-111064, GHSA-2g87-pp6c-29x5; pulls yarl 1.25.1). `pip install --dry-run` resolved exactly these four wheels and
#     `pip check` delta vs stock is empty (MEASURED 2026-10-20, as above). Ray's vendored aiohttp 3.13.5 copy is not pip-reachable
#     and stays (KNOWN-OPEN below).
RUN pip install --no-cache-dir "pyjwt==2.14.0" "urllib3==2.8.0" "aiohttp==3.14.4"
# 4g) openssl / libssl3t64 3.0.13-0ubuntu3.15 -> 3.0.13-0ubuntu3.16 (HIGH CVE-2026-84782): the Ubuntu 24.04 security fix,
#     --only-upgrade so nothing else moves.
RUN apt-get update \
    && apt-get install -y --only-upgrade openssl libssl3t64 \
    && rm -rf /var/lib/apt/lists/*
# 4h) certifi 2026.7.22 -> 2026.10.19 (CRITICAL GHSA-6q48-6c7w-9gw2, published 2026-10-20): the CA-bundle package; its requirers (requests,
#     httpx, httpcore, sentry-sdk) carry no upper bound. `pip install --dry-run` resolves exactly this one wheel and the `pip check` delta vs
#     stock is empty (MEASURED 2026-10-21 in a throwaway container of the pipeline's image public.ecr.aws/hpc-cloud/dynamo-vllm-efa:1.5.0-patched).
RUN pip install --no-cache-dir "certifi==2026.10.19"
# 4i) pillow 12.3.0 -> 13.0.0 (CRITICAL CVE-2026-112403 + HIGH CVE-2026-112397/-112400/-112404/-112895/-112896/-112897, all published
#     2026-10-19; the only fixed release is the 13.0.0 major). pillow is on the VL serving path (vLLM's image loader, the checkpoint's HF
#     image processor, torchvision), so it is bumped, not removed, and the bump was measured rather than assumed: every requirer (vllm,
#     torchvision, transformers, diffusers, mistral_common, scikit-image, imageio) has only a lower bound (>=8.3.2 .. >=11.1.0); `pip check`
#     delta vs stock empty; the resampling constants the consumers use (Image.BILINEAR/NEAREST/LANCZOS/BICUBIC) exist and a resize through
#     each is byte-identical to 12.3.0; ImageOps.exif_transpose/pad/expand, torchvision to_tensor/pil_to_tensor/resize/to_pil_image,
#     transformers resize/to_pil_image/load_image and vLLM's ImageMediaIO run; and the Super VL checkpoint's own image processor
#     (NemotronH_Omni_Reasoning_V3ImageProcessor, the class vLLM wraps at serve time) returns byte-identical pixel_values / num_patches /
#     num_tokens for five test images on 12.3.0 and 13.0.0 (MEASURED 2026-10-21, CPU). A GPU cell on this layer is still a measurement to take.
RUN pip install --no-cache-dir "pillow==13.0.0"
# 4j) uv 0.12.5 (CRITICAL GHSA-hq85-5cpj-mr62, published 2026-10-20; fixed 0.13.4): a package INSTALLER, present twice - the pip wheel's
#     /usr/local/bin/uv + uvx and the base's own 0.12.0 musl build under /opt/uv/bin at the head of PATH. No requirer, and nothing in either
#     tree calls it (templates, .env, run.sh and the runtime bootstrap use pip). Worker-unused -> REMOVED, both copies: a bump would fix the
#     wheel and leave the /opt/uv binary, which `trivy image` flags separately as a Rust binary. pip stays. `pip check` delta vs stock empty
#     (MEASURED 2026-10-21). Restore path for a debugging session: `pip install uv`.
RUN pip uninstall -y uv && rm -rf /opt/uv
# 4k) cosmos-guardrail 0.3.1 + nltk 3.10.3 (HIGH CVE-2026-81726 on nltk, no fixed release): the Cosmos world-model guardrail package is the
#     ONLY requirer of nltk; it is itself required only by vllm-omni (imported lazily, inside its cosmos3 guardrails module) and by diffusers'
#     Cosmos pipelines - nothing on the Nemotron path - and in the stock base it is already non-functional: its hard dependency opencv-python
#     is not installed (stock `pip check` says so). REMOVED. `pip check` delta vs stock = that one line swapped for "vllm-omni 0.28.0rc1
#     requires cosmos-guardrail" (vllm-omni already ships with `av` missing); vllm_omni, vllm, ray and dynamo.vllm.main import afterwards
#     (MEASURED 2026-10-21). Restore path: `pip install cosmos-guardrail opencv-python-headless`.
RUN pip uninstall -y cosmos-guardrail nltk

# KNOWN-OPEN after 4a-4k (HIGH, deliberate; counted by the buildspec's MAX_HIGH; 5 on 2026-10-21 with the 2026-10-21T01:19Z trivy DB,
# all five on the ray 2.55.1 tree): ray 2.55.1 CVE-2026-57516 (fixed 2.56.0 - 2.55.1 is the PP2-PROVEN pin of both trees and this
# image's golden rule is measure-before-bump; the bump is queued behind an E2E PP>1 smoke, do NOT fold it into a CVE pass); ray's
# vendored aiohttp 3.13.5 under ray/_private/runtime_env/agent/thirdparty_files (CVE-2026-69244, CVE-2026-111064, CVE-2026-111066,
# GHSA-2g87-pp6c-29x5; not pip-reachable, rides the same ray pin - replacing only that vendored tree is the next lever if the ceiling
# is ever reached, measured by importing ray and its runtime_env agent plus a `ray start --head` round trip). The counts move with
# the trivy DB date, not only with this file: the gate prints the DB it matched against.

# ---- 5) Final assert: every scenario's prerequisites present; converged ultra layers stay converged ----
RUN set -eux; \
    python3 - <<'PY'
import importlib.metadata as m, importlib.util, os, subprocess
for p, want in {"vllm": "0.28", "ai-dynamo": "1.5", "ray": "2.55.1"}.items():
    got = m.version(p); assert got.startswith(want), f"{p} {got} !~ {want}"
b = importlib.util.find_spec("vllm").submodule_search_locations[0]
assert os.path.isdir(os.path.join(b, "distributed/kv_transfer/kv_connector/v1/nixl")), "nixl connector package missing"
assert os.path.exists("/opt/amazon/efa/bin/fi_info"), "EFA userspace missing"
assert not os.path.exists("/usr/bin/nats-server"), "nats-server still present (step 4a)"
assert not os.path.exists("/usr/local/bin/etcd"), "etcd bins still present (step 4b)"
# Converged-in-GA asserts (ultra's 1.4.0 layers 4c/4d/4f + cubin chmod, retired here — fail loud on regression):
for gone, step in (("mooncake-transfer-engine", "4e"), ("mooncake-transfer-engine-cuda13", "4e"), ("lmcache", "4e"), ("uv", "4j"),
                   ("cosmos-guardrail", "4k"), ("nltk", "4k")):
    try:
        m.version(gone); raise AssertionError(f"{gone} present - step {step} did not remove it")
    except m.PackageNotFoundError:
        pass
assert not os.path.exists("/opt/uv") and not os.path.exists("/usr/local/bin/uv"), \
    "a uv binary is still present - step 4j removes both copies (and with /opt/uv the former /opt/uv/cache location)"
cv = tuple(int(x) for x in m.version("cryptography").split(".")[:1])
assert cv >= (50,), f"venv cryptography {m.version('cryptography')} < 50 - restore ultra's bump layer"
def ver(p): return tuple(int(x) for x in m.version(p).split(".")[:3])
assert ver("pyjwt") >= (2, 14, 0), f"pyjwt {m.version('pyjwt')} < 2.14.0 (step 4f)"
assert ver("urllib3") >= (2, 8, 0), f"urllib3 {m.version('urllib3')} < 2.8.0 (step 4f)"
assert ver("aiohttp") >= (3, 14, 4), f"aiohttp {m.version('aiohttp')} < 3.14.4 (step 4f)"
assert ver("certifi") >= (2026, 10, 19), f"certifi {m.version('certifi')} < 2026.10.19 (step 4h)"
assert ver("pillow") >= (13, 0, 0), f"pillow {m.version('pillow')} < 13.0.0 (step 4i)"
assert m.version("torch").startswith("2.13."), f"torch {m.version('torch')} moved - a step-4 bump drifted the torch pin"
assert m.version("nixl").startswith("1.3."), f"nixl {m.version('nixl')} moved"
ssl = subprocess.run(["dpkg-query", "-W", "-f=${Version}", "libssl3t64"], capture_output=True, text=True).stdout.strip()
assert subprocess.run(["dpkg", "--compare-versions", ssl, "ge", "3.0.13-0ubuntu3.16"]).returncode == 0, f"libssl3t64 {ssl} < 3.0.13-0ubuntu3.16 (step 4g)"
# Cubin dir writability for the non-root worker (ultra's chmod layer, retired: measured writable on this base).
# Checked as a REAL write by the dynamo uid, not a mode read (NVFP4 MoE on SM100 writes here at first call).
import flashinfer_cubin
d = os.path.join(os.path.dirname(flashinfer_cubin.__file__), "cubins")
rc = subprocess.run(["su", "dynamo", "-s", "/bin/bash", "-c", f"mkdir '{d}/.writetest' && rmdir '{d}/.writetest'"]).returncode
assert rc == 0, f"{d} not writable by the dynamo user - restore ultra's chmod -R a+rwX layer"
import ray  # step 4d dropped only the Java jar — the Python driver must still import
print(f"[golden-1.5.0-nemotron] agg + EP16 + P/D disagg (PP1; PP>1 with NIXL_PP_PATCH=1) + E/PD (DYNAMO_EPD_NEMOTRON_PATCH=1) "
      f"prerequisites present; EFA present; worker-unused CVE carriers absent (nats, etcd, launchpadlib, ray_dist.jar, lmcache, mooncake, "
      f"uv, cosmos-guardrail/nltk); measured bumps in place (pyjwt/urllib3/aiohttp/openssl/certifi/pillow); converged layers verified: "
      f"vllm={m.version('vllm')} ai-dynamo={m.version('ai-dynamo')} ray={m.version('ray')}")
PY

USER dynamo
LABEL org.opencontainers.image.description="Golden-image 1.5.0 for the Nemotron family (3.5 Super VL, 3 Ultra): Dynamo 1.5.0 (-efa base, EFA 1.50 + NIXL LIBFABRIC baked) + vLLM 0.28.0 + Ray 2.55.1 + NemotronH_Nano_VL_V2 SupportsPP patch (multi-node PP) + optional NIXL PP>1 pull-path backport (vllm#53360, NIXL_PP_PATCH=1) + optional dynamo encode-worker NemotronH Omni family (disagg/epd, DYNAMO_EPD_NEMOTRON_PATCH=1) + CVE remediation (nats/etcd/launchpadlib/ray_dist.jar/lmcache/mooncake/uv/cosmos-guardrail+nltk removed; pyjwt/urllib3/aiohttp/openssl/certifi/pillow bumped); Dockerfile-only reproducible"
LABEL org.opencontainers.image.source="https://github.com/aws-samples/aws-do-eks/tree/main/Container-Root/eks/deployment/inference/agentic-ai/nemotron/dynamo-vllm-efa"
