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
| 4 | CVE remediation: remove nats-server, etcd, the apt launchpadlib chain, `ray_dist.jar`, lmcache, mooncake, uv, cosmos-guardrail + nltk; bump pyjwt / urllib3 / aiohttp / openssl / certifi / pillow | see the gate below; REMOVE what the workers never execute, measured bumps only, never `.trivyignore` |
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
failure, never a pass. The GATE SUMMARY names the syft / trivy versions and the trivy DB date it matched against and prints the
CRITICAL/HIGH table into the log (also written to `sbom/<image>.gate-summary.txt`); `SCAN_IMAGE=1` adds a report-only `trivy image`. `buildspec.yaml` runs exactly that in CodeBuild with both patch layers ON and publishes
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

## SBOM + CVE gate (2026-10-21, syft 1.55.0, trivy 0.76.0, vulnerability DB UpdatedAt 2026-10-21T01:19Z)

| variant | build args | image id (local build) | SBOM packages | trivy (SBOM scan = the gate) |
|---|---|---|---|---|
| published (`1.5.0-patched`) | `--build-arg NIXL_PP_PATCH=1 --build-arg DYNAMO_EPD_NEMOTRON_PATCH=1` | `sha256:695004fbd5ee8a02197f56a11b97b69eff0c51dfd6acc63a0b61cdcda64e3113` | 687 | CRITICAL 0 / HIGH 5 / MEDIUM 81 / LOW 27 / total 113 — PASS |
| plain (`1.5.0-ray`) | none | `sha256:604764f89fe6b1c6ab5d78407af7f69647b4d8fc5af89a717a3a1a2e1c3201d6` | 687 | CRITICAL 0 / HIGH 5 / MEDIUM 81 / LOW 27 / total 113 — PASS |

The five residual HIGHs all ride the deliberate `ray==2.55.1` pin: ray itself (CVE-2026-57516) and its vendored `aiohttp` 3.13.5
under `ray/_private/runtime_env/agent/thirdparty_files` (CVE-2026-69244, CVE-2026-111064, CVE-2026-111066, GHSA-2g87-pp6c-29x5; not
pip-reachable). They are listed in the Dockerfile's KNOWN-OPEN note; `MAX_HIGH=10` in the buildspec = measured 5 + headroom.

**What the first pipeline run reported, and why.** The pipeline's first build (`public.ecr.aws/hpc-cloud/dynamo-vllm-efa:1.5.0-patched`,
2026-10-21T03:11Z) reported CRITICAL 3 / HIGH 12 / total 127 on the recipe as merged, where the 2026-10-20 gate had measured 0 / 5 / 111 on
the same package set with the same syft 1.55.0 / trivy 0.76.0. The only variable was the trivy vulnerability DB: the 10-20 gate ran
against the 2026-10-20T13:14Z build, the pipeline's fresh install downloaded the 2026-10-21T01:19Z build, and re-scanning the 10-20 SBOM
with that DB gives exactly 3 / 12 / 127. The new findings, all published 2026-10-19/20: certifi 2026.7.22 (CRITICAL), pillow 12.3.0
(CRITICAL + 6 HIGH), uv 0.12.5 (CRITICAL) and a fourth id on ray's vendored aiohttp. Steps 4h-4k answer them the way steps 4a-4g did:
certifi and pillow bumped to the fixed releases (both measured in a throwaway container first: `pip check` delta vs stock empty, the
recipe's imports, and for pillow 13 the Super VL checkpoint's own HF image processor returning byte-identical `pixel_values` on 12.3.0 and
13.0.0), uv removed (a package installer nothing here runs, present twice), and nltk's only carrier cosmos-guardrail removed with it
(the Cosmos world-model guardrail, non-functional in the stock base because its opencv-python dependency is absent). A `trivy sbom` of
the 10-20 image with the 10-20 DB still reports 0 / 5, so **a pipeline report should always be read together with the DB date the gate
now prints** (`tooling : syft …, trivy …, vulnerability DB UpdatedAt …` in the GATE SUMMARY and in `sbom/<image>.gate-summary.txt`).

**`trivy image` is a different universe, by design, not a gate.** A full image walk of the same image (`SCAN_IMAGE=1 ./build-sbom-scan.sh`,
report-only, 3 min on this host with a warm docker cache) reports CRITICAL 27 / HIGH 558 / total 4888 on the published variant. The difference is structural, not
unfixed work: (1) Ubuntu packages whose source name differs from the binary name — above all `linux-libc-dev` (source `linux`, 4342
kernel CVEs attributed to the header package; 21 CRITICAL, 12 of them with no fixed version) — are invisible to the SBOM scan because
trivy's purl parser (v0.76.0 `pkg/purl/purl.go`) does not read syft's `upstream=` qualifier; the headers are inert in a container and
`libc6-dev` depends on them, so they stay. (2) The base ships NVIDIA's legal SBOM at `/legal/osrb.cdx.json`, and `trivy image` reports
its components (the BASE's pyjwt 2.13.0, lmcache 0.5.4, pillow 12.3.0, uv 0.12.5, openssl 3.0.13-0ubuntu3.15 …) as if installed, after
steps 4e-4k removed or bumped them. (3) The remaining real findings are the same ray tree as above. The SBOM scan stays the gate; the
image-scan report is written beside the SBOMs when asked for, so both views are on record.

`sbom/` is git-ignored: the SBOMs are build artifacts, regenerated by every run.
