# dynamo-vllm-efa — the ONE container recipe for the Nemotron family on Dynamo 1.5.0 / vLLM 0.28.0 / EFA

One `Dockerfile` serves both [`../super`](../super) (Nemotron 3.5 Super VL 120B-A12B) and [`../ultra`](../ultra) (Nemotron 3 Ultra
550B-A55B), on the public NGC base `nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.5.0-efa` (Dynamo 1.5.0, vLLM 0.28.0, EFA 1.50.0, NIXL 1.3.2
with the LIBFABRIC plugin). It is the former `super/dynamo-vllm-efa/Dockerfile.ray` generalized to the family (2026-10-20); the
former per-tree recipes are preserved in those folders' git history (their READMEs name the commit).

| step | what | why / measured where |
|---|---|---|
| 0 | base asserts (vLLM 0.28.x, Dynamo 1.5.x, transformers >= 5.13, matched flashinfer pair, runai-model-streamer, the Super Omni architecture alias + `nemotron_h_mtp`, `NemotronHForCausalLM`) | fail at build, not at serve, if the base moves |
| 1 | EFA userspace + aws-ofi-nccl + NIXL LIBFABRIC plugin: assert-only | baked by the `-efa` base; the templates carry the `FI_*` / `NCCL_*` env |
| 2 | `ray[default]==2.55.1` | the PP2-proven pin of both trees (`--distributed-executor-backend ray`) |
| 3 | `NemotronH_Nano_VL_V2` SupportsPP patch (always on) | every super PP>1 shape; a no-op for the text-only 550B |
| 3b | `--build-arg NIXL_PP_PATCH=1`: the vllm-project/vllm#53360 backport onto 0.28.0 | PP>1 prefill and decode of a hybrid-Mamba model over NIXL (`disagg/lws-2pp`, `lws-pp2`, `dgd-grove-pp2`, both trees); wire version 7 -> 10, so both roles need the same build |
| 3c | `--build-arg DYNAMO_EPD_NEMOTRON_PATCH=1`: dynamo encode-worker NemotronH Omni family + vLLM image_embeds fixes | `super/disagg/epd` |
| 4 | CVE remediation: remove nats-server, etcd, the apt launchpadlib chain, `ray_dist.jar`, lmcache, mooncake; bump pyjwt / urllib3 / aiohttp / openssl | see the gate below; REMOVE what the workers never execute, measured bumps only, never `.trivyignore` |
| 5 | final assert (pins intact, carriers gone, bumps present, cubin dir writable by the `dynamo` user) | fail loud on regression |

## Build

```bash
docker build -t dynamo-vllm-efa:1.5.0-ray .                                                                  # ray + SupportsPP only
docker build --build-arg NIXL_PP_PATCH=1 -t dynamo-vllm-efa:1.5.0-ray-nixlpp .                              # + PP>1 disagg
docker build --build-arg NIXL_PP_PATCH=1 --build-arg DYNAMO_EPD_NEMOTRON_PATCH=1 -t dynamo-vllm-efa:1.5.0-patched .   # + epd = the published image
DOCKER_BUILD_ARGS="--build-arg NIXL_PP_PATCH=1 --build-arg DYNAMO_EPD_NEMOTRON_PATCH=1" ./build-sbom-scan.sh    # build + SBOM + CVE gate
```

`build-sbom-scan.sh` builds (forwarding `BASE` and `DOCKER_BUILD_ARGS` as `--build-arg`), writes the SBOM (SPDX + CycloneDX) with
syft into `sbom/`, scans the CycloneDX SBOM with trivy and fails on any CRITICAL (or on HIGH above `MAX_HIGH`); a missing report is a
failure, never a pass. `buildspec.yaml` runs exactly that in CodeBuild with both patch layers ON and publishes
`dynamo-vllm-efa:1.5.0-patched` (`REGISTRY` / `IMAGE` are the maintainer's call; the SBOMs and the trivy report are the build artifacts).

## What is measured, and what is not

Measured on 1.5.0-efa builds of these steps (node-recorded digests; `../super/test/RESULTS.md` footnotes):

| build | digest | cells |
|---|---|---|
| no build args | `sha256:bb36e7449c2f…` | every non-PP super cell on the p5e EKS Auto Mode cluster (2026-10-19/20) and the CGK p5en Dynamo 1.5.1 spot-check |
| `NIXL_PP_PATCH=1` | `sha256:43561d30cf85…` | every PP>1 disagg cell: p5e footnotes 56-61, CGK 102-104, 106, 108, 109 |
| + `DYNAMO_EPD_NEMOTRON_PATCH=1` | `sha256:8f66005fa237…` | the two `disagg/epd` cells, CGK 101 / 105 |

**Not measured** — stated gates: Nemotron-3 Ultra 550B has not been served on any 1.5.0 image (its measured rows are on
`dynamo-vllm-efa:1.4.0-patched`, vLLM 0.26, and its `.env` stays there; `TAG=":1.5.0-patched"` is the override to test); the
consolidated build itself has not been run on a GPU cell — it was built, SBOM-ed and CVE-gated only.

## SBOM + CVE gate (2026-10-20, syft 1.55.0, trivy 0.76.0, DB UTC)

| variant | build args | image id | SBOM packages | trivy (SBOM scan) |
|---|---|---|---|---|
| published (`1.5.0-patched`) | `--build-arg NIXL_PP_PATCH=1 --build-arg DYNAMO_EPD_NEMOTRON_PATCH=1` | `sha256:21e7c406237cadbea5e319caa2e1ba2b5de77e03f8b5fc27ddcf75dcc294cb61` | 2774 | CRITICAL 0 / HIGH 5 / MEDIUM 80 / LOW 26 / total 111 |
| plain (`1.5.0-ray`) | none | `sha256:846bf7012cca39c79c4b9eaf414ff536b0f6d048be9b93d4591e4b3ab62d9ced` | 2774 | CRITICAL 0 / HIGH 5 / MEDIUM 80 / LOW 26 / total 111 |

Before step 4e-4g the same two builds scanned CRITICAL 2 / HIGH 34 / MEDIUM 103 / LOW 33 / total 172 — the 1.5.0 base ships `lmcache` 0.5.4 (CRITICAL
CVE-2026-105192), `pyjwt` 2.13.0 (CRITICAL CVE-2026-102268), and Mooncake under the wheel name `mooncake-transfer-engine-cuda13`
whose Go `libetcd_wrapper.so` carries 19 HIGH (the former assert checked the old wheel name). Both connectors are optional KV
transports no template uses (every disaggregated template moves KV through `NixlConnector` LIBFABRIC), so they are removed, not
bumped (lmcache's fix release would pull a different NCCL); pyjwt, urllib3, aiohttp and openssl get the measured fix versions
(`pip check` delta empty, vllm/torch/ray/nixl pins unchanged, imports verified). The residual HIGHs are deliberate and listed in the
Dockerfile's KNOWN-OPEN note: ray 2.55.1 (CVE-2026-57516; the PP2-proven pin, bump only behind an E2E PP>1 smoke), ray's vendored
aiohttp 3.13.5 (not pip-reachable), nltk 3.10.3 (no fixed release). `MAX_HIGH=10` in the buildspec = measured 5 + headroom;
ratchet it after each pipeline report.

`sbom/` is git-ignored: the SBOMs are build artifacts, regenerated by every run.
