# dynamo-vllm-efa (super) — the recipe moved one level up

The container recipe for this tree is now shared with [`../../ultra`](../../ultra): [`../../dynamo-vllm-efa/`](../../dynamo-vllm-efa/)
(`Dockerfile`, `patches/`, `build-sbom-scan.sh`, `buildspec.yaml`, `README.md`). It is this folder's former `Dockerfile.ray`
generalized to the Nemotron family (2026-10-20); the pipeline builds it with both opt-in patches on as `dynamo-vllm-efa:1.5.0-patched`.

The files this folder used to carry — `Dockerfile` (the 1.5.0-efa golden image without Ray or patches), `Dockerfile.ray`,
`patches/` (0001-0004, `apply_pp_patch.py`, `runtime-bootstrap.sh`, the two verifiers), `build-sbom-scan.sh`, `buildspec.yaml`,
`.gitignore` — are preserved in this folder's git history at commit `5300ed0`:

```bash
git show 5300ed0:Container-Root/eks/deployment/inference/agentic-ai/nemotron/super/dynamo-vllm-efa/Dockerfile.ray
```

The footnotes in [`../test/RESULTS.md`](../test/RESULTS.md) that name `../dynamo-vllm-efa/Dockerfile.ray` describe the images built
from those files; the node-recorded digests they cite are listed, build by build, in the shared recipe's header.
