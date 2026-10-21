# dynamo-vllm-efa (ultra) — the recipes live one level up

The image this tree defaults to, `public.ecr.aws/hpc-cloud/dynamo-vllm-efa:1.4.0-patched` (the `TAG` in [`../agg/.env`](../agg/.env) and
[`../disagg/.env`](../disagg/.env); every row of [`../test/RESULTS.md`](../test/RESULTS.md) was measured on it), has its recipe in
[`../../dynamo-vllm-efa/1.4.0-patched/`](../../dynamo-vllm-efa/1.4.0-patched/): `nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.4.0-efa` (Dynamo 1.4.0 /
vLLM 0.26 / EFA 1.49) + Ray 2.55.1 + the strict 0.26-era NIXL pull-path pipeline-parallel patch layer (PP>1 disaggregation) + CVE removals + the
NVFP4 cubin-dir fix, with its own `buildspec.yaml` (a second CodeBuild project) that runs the shared gate `../../dynamo-vllm-efa/build-sbom-scan.sh`
with `CONTEXT=.`. The build and pipeline lines, the measured gate numbers and what is unmeasured are in that folder's README.

The shared recipe [`../../dynamo-vllm-efa/`](../../dynamo-vllm-efa/) (`Dockerfile`, `patches/`, `build-sbom-scan.sh`, `buildspec.yaml`) builds the
1.5.0 line for [`../../super`](../../super) and this tree on `nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.5.0-efa` (Dynamo 1.5.0 / vLLM 0.28.0); its
`--build-arg NIXL_PP_PATCH=1` layer is the 0.28.0 successor of the 0.26 patch set, which does not apply to the rewritten 0.28.0 nixl package.
`TAG=":1.5.0-patched"` is an override to test, not the default (see the `.env` comments).

History: this folder carried the 1.4.0-patched recipe until 2026-10-20 (last at commit `5300ed0`, restored as the sibling folder above; its
`vex.openvex.json`, a stale `not_affected` statement for a vLLM 0.20.1 CVE, was not carried forward). On a Dynamo 1.3.1 platform the previous
image `dynamo-vllm-efa:1.3.1-patched` applies; its recipe is in this folder's history as well.
