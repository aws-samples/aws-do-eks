# dynamo-vllm-efa (ultra) — the recipe moved one level up

The container recipe for this tree is now shared with [`../../super`](../../super): [`../../dynamo-vllm-efa/`](../../dynamo-vllm-efa/)
(`Dockerfile`, `patches/`, `build-sbom-scan.sh`, `buildspec.yaml`, `README.md`), on `nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.5.0-efa`
(Dynamo 1.5.0 / vLLM 0.28.0). Its `--build-arg NIXL_PP_PATCH=1` layer is the 0.28.0 successor of the 0.26-era PP>1 patches this
folder carried. **It has not been measured with Nemotron-3 Ultra 550B**: the measured rows in [`../test/RESULTS.md`](../test/RESULTS.md)
were taken on the public image `dynamo-vllm-efa:1.4.0-patched` built from this folder's former recipe, and the `.env` files still
default to that image (`TAG=":1.5.0-patched"` is an override to test, not the default).

The files this folder used to carry are preserved in its git history at commit `5300ed0`:

- `Dockerfile` — `vllm-runtime:1.4.0-efa` (vLLM 0.26 / Dynamo 1.4.0 / EFA 1.49) + Ray 2.55.1 + the strict `patches/` layer + CVE
  removals + the NVFP4 cubin-dir fix = `dynamo-vllm-efa:1.4.0-patched` (0 CRITICAL / 2 HIGH measured 2026-08-25).
- `patches/0001-nixl-pull-path-pipeline-parallel.vllm.diff` — pull-path pipeline-parallel producers, hybrid-Mamba (HMA) region members,
  symmetric PPxPP consumers against the vLLM v0.26.0 nixl package (NIXL_CONNECTOR_VERSION 5 -> 6); verified on 4x B200 with 550B
  (PP2 prefill -> PP1 decode and PP2/PP2, byte-identical temperature-0 output, byte-parity KV reads). It does not apply to the
  rewritten 0.28.0 package.
- `build-sbom-scan.sh`, `buildspec.yaml`, `.gitignore` — the build + SBOM + CVE-gate pipeline, now shared.
- `vex.openvex.json` — a `not_affected` statement for CVE-2026-48746 against `pkg:pypi/vllm@0.20.1+cu129`; the CVE is fixed in
  vLLM 0.22.0 and every image built from this folder since carried 0.26.0 or newer, so the statement was already stale and is not
  carried into the shared recipe.

```bash
git show 5300ed0:Container-Root/eks/deployment/inference/agentic-ai/nemotron/ultra/dynamo-vllm-efa/Dockerfile
```

On a Dynamo 1.3.1 platform the previous image `dynamo-vllm-efa:1.3.1-patched` applies; its recipe is in the same folder's history.
