# dynamo-vllm-efa:1.4.0-patched — the ultra image, as a buildable sibling of the shared 1.5.0 recipe

This folder builds the image [`../../ultra`](../../ultra) defaults to (`TAG=":1.4.0-patched"` in `agg/.env` and `disagg/.env`) and was
measured on (every row of [`../../ultra/test/RESULTS.md`](../../ultra/test/RESULTS.md)): `nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.4.0-efa`
(Dynamo 1.4.0 / vLLM 0.26.0 / EFA 1.49 / NIXL 1.3.1) + Ray 2.55.1 + the strict 0.26-era NIXL pull-path pipeline-parallel patch layer (PP>1
disaggregation, NIXL connector v6, always on) + CVE remediation + the NVFP4 cubin-dir fix. It exists beside the shared recipe
[`../Dockerfile`](../Dockerfile) because that one builds on `vllm-runtime:1.5.0-efa` (vLLM 0.28.0) and asserts it, and the 0.26 patch set
does not apply to the rewritten 0.28.0 nixl package; the 1.5.0 line has not been measured with the 550B model. The files are the ones
`nemotron/ultra/dynamo-vllm-efa/` carried until 2026-10-20 (preserved at `5300ed0`), plus the 2026-10-21 CVE steps 4h-4m below.

| step | what | why / measured where |
|---|---|---|
| 0 | base asserts (vLLM 0.26.x, Dynamo 1.4.x, transformers >= 5.13, matched flashinfer pair) | fail at build, not at serve, if the base moves |
| 1 | EFA userspace + aws-ofi-nccl: assert-only (installer >= 1.49.0) | baked by the `-efa` base; the templates carry the `FI_*` / `NCCL_*` env |
| 2 | `ray==2.55.1` | the PP2-proven pin (`--distributed-executor-backend ray`) |
| 3 | `patches/0001-nixl-pull-path-pipeline-parallel.vllm.diff`, strict `--fuzz=0` | PP>1 prefill and decode of the hybrid-Mamba 550B over NIXL (`disagg/lws-2pp`, `lws-pp2`, `dgd-grove-pp2`); markers asserted after apply |
| 4a-4g | CVE removals of 2026-08-25: nats-server, etcd, mooncake, the uv cache, the apt launchpadlib chain, ray_dist.jar; cryptography >= 50 | REMOVE what the workers never execute, measured bumps only, never `.trivyignore` |
| 4h-4m | 2026-10-21: lmcache and uv removed; pyjwt / urllib3 / aiohttp, openssl, certifi, pillow bumped | the advisories published after the 08-25 pass; each measured in a throwaway container first (below) |
| 5 | final assert (pins intact, carriers gone, bumps present) | fail loud on regression |
| 6 | flashinfer cubin dir writable by the `dynamo` user | NVFP4 MoE on SM100 writes there at first call |

## Build

```bash
# local, through the shared gate (build -> syft SBOM -> trivy gate -> PASS record), from this folder:
CONTEXT=. IMAGE=dynamo-vllm-efa:1.4.0-patched BASE=nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.4.0-efa GATE_SEVERITY=CRITICAL,HIGH MAX_HIGH=10 ../build-sbom-scan.sh
# the image alone:
docker build -t dynamo-vllm-efa:1.4.0-patched .
```

`../build-sbom-scan.sh` with `CONTEXT=.` builds this folder (forwarding `BASE` as `--build-arg`), writes the SBOM (SPDX + CycloneDX) into
`sbom/` here, scans the CycloneDX SBOM with trivy and fails on any CRITICAL or on HIGH above `MAX_HIGH`; a PASS writes
`sbom/<image>.gate-pass.txt` for the exact image id. In CodeBuild the **shared** [`../buildspec.yaml`](../buildspec.yaml) builds this folder
when its `RECIPE` variable is `1.4.0-patched` (a start-build environment override of the existing project, or a project-level value; nothing
else to set): `../select-recipe.sh` sources this folder's [`recipe.env`](recipe.env) (`BASE=…vllm-runtime:1.4.0-efa`,
`IMAGE=dynamo-vllm-efa:1.4.0-patched`, no build args) in place of the buildspec's 1.5.0 values, builds this folder through the shared gate
and writes the SBOMs + PASS record into `../sbom/` (the build artifacts), then publishes `dynamo-vllm-efa:1.4.0-patched` (`REGISTRY` /
`IMAGE` stay the maintainer's call). With `RECIPE` unset, the default, the same buildspec builds `dynamo-vllm-efa:1.5.0-patched`; there is
no second buildspec. **The push is conditioned on the gate:** post_build is one command that pushes only when the build phase succeeded AND the PASS
record exists for the exact image id being pushed; otherwise it exits nonzero and the run is red.

## Measured (2026-10-21, GPU-free: docker build + syft 1.55.0 + trivy 0.76.0, vulnerability DB UpdatedAt 2026-10-21T19:18:22Z)

| build | image id (local) | SBOM packages | trivy (SBOM scan = the gate) |
|---|---|---|---|
| this folder as of `5300ed0` (steps 0-4g, 6) | `sha256:320cde4040b4…` | 2716 | CRITICAL 5 / HIGH 22 / total 169 — FAIL |
| + 4h lmcache removed | | | CRITICAL 4 / HIGH 22 / total 168 — FAIL |
| + 4i pyjwt / urllib3 / aiohttp | | | CRITICAL 3 / HIGH 12 / total 145 — FAIL |
| + 4j openssl | | | CRITICAL 3 / HIGH 11 / total 134 — FAIL |
| + 4k certifi | | | CRITICAL 2 / HIGH 11 / total 133 — FAIL |
| + 4l pillow 13 | | | CRITICAL 1 / HIGH 5 / total 124 — FAIL |
| **+ 4m uv removed = this folder** | `sha256:db7bfb0e6c19…` | 658 | **CRITICAL 0 / HIGH 5 / total 121 — PASS** |

The gate-1 CRITICALs were certifi 2026.7.22, lmcache 0.5.2, pillow 12.3.0, pyjwt 2.13.0 and uv 0.11.32 — the same advisories (published
2026-10-19/20 and after the August pass) that the shared recipe's steps 4e-4j answer; cosmos-guardrail and nltk, which the shared recipe
also removes, are not present on `1.4.0-efa`. Each 4h-4m step was measured in a throwaway container of the gate-1 image before it was
committed: `pip check` delta vs stock empty for every step, `pip install --dry-run` resolving exactly the named wheels (plus yarl 1.25.1 with
aiohttp), and vllm, ray, the KV-connector factory, the NIXL pull/base workers, `nemotron_h`, `vllm.multimodal`, torchvision, PIL and
`dynamo.vllm.main` importing afterwards. The 5 residual finding(s) of the final build: HIGH aiohttp 3.13.5 CVE-2026-111064; HIGH aiohttp 3.13.5 CVE-2026-111066; HIGH aiohttp 3.13.5 CVE-2026-69244; HIGH aiohttp 3.13.5 GHSA-2g87-pp6c-29x5; HIGH ray 2.55.1 CVE-2026-57516. All ride the deliberate `ray==2.55.1` pin (ray itself and its vendored aiohttp 3.13.5 under `ray/_private/runtime_env/agent/thirdparty_files`, not pip-reachable), listed in the Dockerfile's KNOWN-OPEN note; `MAX_HIGH=10` in the buildspec = measured 5 + headroom. The SBOM package count drops from 2716 to 658 with step 4m because syft lists the uv binary's
embedded Rust crates as 2056 `cargo` entries; the Python package count moves from 302 to 300 (lmcache, uv) and the 341 Debian packages are unchanged.

**What the published image is.** `public.ecr.aws/hpc-cloud/dynamo-vllm-efa:1.4.0-patched` (manifest `sha256:8332b609a2ed…`, the digest every
RESULTS.md row recorded) was created 2026-08-23T03:54Z from the previous revision of this Dockerfile (35ede59): its layer history carries
step 4a (nats-server) and nothing else of step 4. Steps 4b-4g were committed on 2026-08-25 (ac8de2d) and never published — a probe of the
pulled image shows etcd, mooncake 0.3.10.post2, `/opt/uv/cache`, python3-launchpadlib, cryptography 49.0.0 and `ray_dist.jar` present. Under
the same DB the published image scans at CRITICAL 6 / HIGH 87 / total 307 (3124 packages); the HIGHs beyond this folder's are the Go and
Java carriers (Go stdlib in etcd and mooncake's libetcd_wrapper, x/net, grpc, jackson in ray_dist.jar, the apt cryptography/httplib2/pyjwt
chain). So a build of this folder reproduces the published image's core — vllm 0.26.0, ai-dynamo 1.4.0, ray 2.55.1, nixl 1.3.1, NIXL
connector v6, EFA 1.49.0, torch 2.11.0+cu130, transformers 5.14.1 — but not its full package set, by design of the removals; its digest
differs in any case. To rebuild exactly what was published, `git show 35ede59:Container-Root/eks/deployment/inference/agentic-ai/nemotron/ultra/dynamo-vllm-efa/Dockerfile`.

**Not measured.** The image this folder builds today has not been served on a GPU: the lane that restored it was GPU-free. The published
`1.4.0-patched` stays the measured image until a rebuild is deployed and measured (the `.env` default does not change with this folder);
the pillow 13 and the other 4h-4m layers carry the same caveat as the shared recipe's.

`sbom/` is git-ignored: the SBOMs are build artifacts, regenerated by every run.
