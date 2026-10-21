#!/usr/bin/env bash
# build-sbom-scan.sh — pipeline gate for the ONE Nemotron dynamo-vllm-efa image (../super and ../ultra):
#   reproducible build  +  SBOM (SPDX + CycloneDX)  +  CVE gate (0 CRITICAL, HIGH counted).
#
# Author: Anton Alexander
#
# Designed to be dropped straight into a build pipeline: no interactive steps, every
# artifact written to $OUTDIR, and a nonzero exit on any gate failure.
#
#   ./build-sbom-scan.sh                                   # build (Dockerfile defaults: no patches) + SBOM + gate on CRITICAL
#   DOCKER_BUILD_ARGS="--build-arg NIXL_PP_PATCH=1 --build-arg DYNAMO_EPD_NEMOTRON_PATCH=1" ./build-sbom-scan.sh
#                                                          # the published "-patched" image (what buildspec.yaml runs)
#   BASE=nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.5.0-efa ./build-sbom-scan.sh   # pin/override the base (passed as --build-arg BASE)
#   IMAGE=dynamo-vllm-efa:1.5.0-patched ./build-sbom-scan.sh --scan-only          # scan a prebuilt image
#   GATE_SEVERITY=CRITICAL,HIGH ./build-sbom-scan.sh       # stricter gate
#   MAX_HIGH=40 ./build-sbom-scan.sh                       # also fail if HIGH exceeds a ceiling
#   SCAN_IMAGE=1 ./build-sbom-scan.sh                      # + a report-only `trivy image` of the built image beside the gate artifacts
#
# The gate's counts depend on the trivy vulnerability DB in use as much as on the image (2026-10-21: the same image and tools went
# from 0 CRITICAL / 5 HIGH to 3 / 12 between the 2026-10-20T13:14Z and the 2026-10-21T01:19Z DB builds), so the summary names
# the syft / trivy versions and the DB UpdatedAt and prints the CRITICAL/HIGH table into the log; both also land in
# $OUTDIR/<image>.gate-summary.txt next to the SBOMs.
#
# The gate's verdict is also a FILE: $OUTDIR/<image>.gate-pass.txt is written ONLY after every check passed (image id, counts,
# tooling, DB, thresholds) and is removed at the start of every run, so a stale PASS cannot leak into a later decision. The push
# (buildspec.yaml post_build) requires that record for the image id it is about to push - a nonzero exit alone is not what
# conditions the push (2026-10-21: the pipeline pushed a 3-CRITICAL image because its push commands ran after a failed gate).
#
# Exit codes: 0 pass | 2 build failed | 3 gate could not be evaluated (never a silent pass)
#             4 CVE gate failed on severity | 5 HIGH ceiling exceeded
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${IMAGE:-dynamo-vllm-efa:1.5.0-patched}"
GATE_SEVERITY="${GATE_SEVERITY:-CRITICAL}"
MAX_HIGH="${MAX_HIGH:-}"                       # empty = report HIGH, do not gate on it
OUTDIR="${OUTDIR:-$HERE/sbom}"
# Extra `docker build` arguments, e.g. the opt-in patch ARGs (see the Dockerfile header). Default empty = the
# Dockerfile's own ARG defaults (both patches OFF). BASE, when set in the environment (the buildspec sets it), is
# forwarded as --build-arg BASE= so the pinned base is the one that was actually built, not just the one printed.
DOCKER_BUILD_ARGS="${DOCKER_BUILD_ARGS:-}"
BASE="${BASE:-}"
SCAN_IMAGE="${SCAN_IMAGE:-0}"                # 1 = also run `trivy image` on the built image, REPORT-ONLY (see step 4)
TRIVY_TIMEOUT="${TRIVY_TIMEOUT:-120m}"       # for the optional image walk
SCAN_ONLY=0
[ "${1:-}" = "--scan-only" ] && SCAN_ONLY=1

SAFE_TAG="$(echo "$IMAGE" | tr '/:' '__')"
SBOM_SPDX="$OUTDIR/${SAFE_TAG}.spdx.json"
SBOM_CDX="$OUTDIR/${SAFE_TAG}.cdx.json"
CVE_JSON="$OUTDIR/${SAFE_TAG}.trivy.json"
CVE_TXT="$OUTDIR/${SAFE_TAG}.trivy.txt"
IMG_JSON="$OUTDIR/${SAFE_TAG}.trivy-image.json"
IMG_TXT="$OUTDIR/${SAFE_TAG}.trivy-image.txt"
GATE_TXT="$OUTDIR/${SAFE_TAG}.gate-summary.txt"
GATE_PASS="$OUTDIR/${SAFE_TAG}.gate-pass.txt"   # written ONLY on PASS (see the end); the push keys on it
mkdir -p "$OUTDIR"
rm -f "$GATE_PASS"                               # a previous run's PASS must never speak for this one

for t in syft trivy docker; do
  command -v "$t" >/dev/null 2>&1 || { echo "FATAL: $t not on PATH"; exit 3; }
done

# ---- 1) build -------------------------------------------------------------------------
if [ "$SCAN_ONLY" = 0 ]; then
  BUILD_ARGS=()
  [ -n "$BASE" ] && BUILD_ARGS+=(--build-arg "BASE=$BASE")
  # shellcheck disable=SC2206  # DOCKER_BUILD_ARGS is a deliberate space-separated list of flags
  [ -n "$DOCKER_BUILD_ARGS" ] && BUILD_ARGS+=($DOCKER_BUILD_ARGS)
  echo "[1/3 BUILD] docker build ${BUILD_ARGS[*]:-} -> $IMAGE"
  docker build "${BUILD_ARGS[@]}" -t "$IMAGE" "$HERE" || { echo "[1/3 BUILD] FAIL"; exit 2; }
else
  echo "[1/3 BUILD] skipped (--scan-only)"
  docker image inspect "$IMAGE" >/dev/null 2>&1 || { echo "FATAL: $IMAGE not present"; exit 2; }
fi
IMAGE_ID="$(docker image inspect --format '{{.Id}}' "$IMAGE")"

# ---- 2) SBOM --------------------------------------------------------------------------
echo "[2/3 SBOM] syft -> SPDX + CycloneDX ..."
syft "docker:$IMAGE" -o "spdx-json=$SBOM_SPDX" -o "cyclonedx-json=$SBOM_CDX" -q

# ---- 3) CVE gate ----------------------------------------------------------------------
# Scan the SBOM, NOT the image. A `trivy image` scan walks every layer's filesystem and
# reliably hits the default timeout on an image this size (~33GB); the timeout produced an
# EMPTY report, an empty count, and `[ "" -gt 0 ]` fell through to a FALSE PASS. The SBOM
# scan is filesystem-free and covers the exact package set syft recorded.
echo "[3/3 GATE] trivy sbom scan ($SBOM_CDX) ..."
trivy sbom --scanners vuln --timeout 30m --format json -o "$CVE_JSON" "$SBOM_CDX" || true
trivy sbom --scanners vuln --timeout 30m --severity "$GATE_SEVERITY" \
      --format table -o "$CVE_TXT" "$SBOM_CDX" || true

# FAIL-LOUD: a missing/empty report is a gate FAILURE, never a silent pass.
if [ ! -s "$CVE_JSON" ]; then
  echo "[3/3 GATE] FAIL — trivy produced no CVE report ($CVE_JSON missing/empty)."
  echo "[3/3 GATE]        the scan errored; refusing to claim 0 CRITICAL."
  exit 3
fi

# Python exits NONZERO on any parse problem so the gate fails loud, not silent.
COUNTS="$(python3 - "$CVE_JSON" <<'PY'
import json, sys, collections
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    sys.stderr.write("trivy JSON parse failed: %s\n" % e); sys.exit(1)
sev = collections.Counter()
for r in (d.get("Results") or []):
    for v in (r.get("Vulnerabilities") or []):
        sev[(v.get("Severity") or "UNKNOWN").upper()] += 1
print("%d %d %d" % (sev["CRITICAL"], sev["HIGH"], sum(sev.values())))
PY
)" || { echo "[3/3 GATE] FAIL — could not parse $CVE_JSON"; exit 3; }
read -r CRIT HIGH TOTAL <<<"$COUNTS"

PKG_COUNT="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1])).get("packages",[])))' "$SBOM_SPDX" 2>/dev/null || echo '?')"

# Tool + DB provenance. Read AFTER the scan: that is when trivy has downloaded (or kept) the DB it actually matched against.
SYFT_VER="$(syft version 2>/dev/null | awk '/^Version:/{print $2; exit}')"
TRIVY_VER="$(trivy --version 2>/dev/null | awk '/^Version:/{print $2; exit}')"
TRIVY_DB="$(trivy --version 2>/dev/null | awk '/UpdatedAt:/{print $2 "T" substr($3,1,8) "Z"; exit}')"

# ---- 4) optional, REPORT-ONLY: `trivy image` on the same image ------------------------
# The SBOM gate above is the contract. A full image walk sees a different universe that is not actionable in this recipe:
# Ubuntu packages whose source name differs from the binary name (trivy's purl parser does not read syft's `upstream=`
# qualifier - above all linux-libc-dev -> `linux`, thousands of kernel CVEs on an inert header package that libc6-dev depends
# on), the components of SBOM files shipped inside the image (/legal/osrb.cdx.json lists the base's PRE-remediation versions)
# and Rust binaries. Measured 2026-10-21 on this 33 GB image: 3 min with a warm docker cache. Written beside the gate artifacts
# and printed, never counted into the gate.
IMG_CRIT="-"; IMG_HIGH="-"; IMG_TOTAL="-"
if [ "$SCAN_IMAGE" = 1 ]; then
  echo "[4/3 IMAGE] trivy image --scanners vuln --timeout $TRIVY_TIMEOUT $IMAGE (report-only) ..."
  trivy image --scanners vuln --timeout "$TRIVY_TIMEOUT" --format json -o "$IMG_JSON" "$IMAGE" || true
  trivy image --scanners vuln --timeout "$TRIVY_TIMEOUT" --severity "$GATE_SEVERITY" --format table -o "$IMG_TXT" "$IMAGE" || true
  if [ -s "$IMG_JSON" ]; then
    read -r IMG_CRIT IMG_HIGH IMG_TOTAL <<<"$(python3 - "$IMG_JSON" <<'PY'
import json, sys, collections
sev = collections.Counter()
for r in (json.load(open(sys.argv[1])).get("Results") or []):
    for v in (r.get("Vulnerabilities") or []):
        sev[(v.get("Severity") or "UNKNOWN").upper()] += 1
print("%d %d %d" % (sev["CRITICAL"], sev["HIGH"], sum(sev.values())))
PY
)" || { IMG_CRIT="?"; IMG_HIGH="?"; IMG_TOTAL="?"; }
  else
    echo "[4/3 IMAGE] trivy image produced no report (timeout?) - report-only, the gate below is unaffected"
  fi
fi

{
echo
echo "=============================== GATE SUMMARY ==============================="
echo "image      : $IMAGE ($IMAGE_ID)"
echo "build args : ${DOCKER_BUILD_ARGS:-<none>}${BASE:+  BASE=$BASE}"
echo "tooling    : syft ${SYFT_VER:-?}, trivy ${TRIVY_VER:-?}, vulnerability DB UpdatedAt ${TRIVY_DB:-?}"
echo "sbom_spdx  : $SBOM_SPDX ($PKG_COUNT packages)"
echo "sbom_cdx   : $SBOM_CDX"
echo "cve_report : $CVE_JSON / $CVE_TXT"
echo "CRITICAL=$CRIT  HIGH=$HIGH  TOTAL=$TOTAL   (gate severity: $GATE_SEVERITY; the SBOM scan is the gate)"
if [ "$SCAN_IMAGE" = 1 ]; then
  echo "image scan : CRITICAL=$IMG_CRIT  HIGH=$IMG_HIGH  TOTAL=$IMG_TOTAL   (trivy image, REPORT-ONLY: $IMG_JSON / $IMG_TXT)"
fi
echo "==========================================================================="
} | tee "$GATE_TXT"
# The CRITICAL/HIGH table into the log, so a failing pipeline run names its CVEs without opening artifacts.
if [ -s "$CVE_TXT" ]; then
  echo "---- $GATE_SEVERITY findings (SBOM scan) ----"; cat "$CVE_TXT"; echo "---------------------------------------------"
fi

if [ "$CRIT" -gt 0 ]; then
  echo "GATE FAIL — $CRIT CRITICAL CVE(s). See $CVE_TXT."
  echo "Fix by REMOVING the unused component (as with /usr/bin/nats-server), not by"
  echo ".trivyignore — an ignore file makes the 0-CRITICAL claim untrue."
  exit 4
fi
if [ -n "$MAX_HIGH" ] && [ "$HIGH" -gt "$MAX_HIGH" ]; then
  echo "GATE FAIL — HIGH=$HIGH exceeds MAX_HIGH=$MAX_HIGH."
  exit 5
fi
# PASS record: the only artifact the push accepts. One key=value per line; image_id is matched exactly by the buildspec.
{
  echo "image=$IMAGE"
  echo "image_id=$IMAGE_ID"
  echo "build_args=${DOCKER_BUILD_ARGS:-<none>}${BASE:+  BASE=$BASE}"
  echo "critical=$CRIT"
  echo "high=$HIGH"
  echo "total=$TOTAL"
  echo "gate_severity=$GATE_SEVERITY"
  echo "max_high=${MAX_HIGH:-<not gated>}"
  echo "tooling=syft ${SYFT_VER:-?}, trivy ${TRIVY_VER:-?}, vulnerability DB UpdatedAt ${TRIVY_DB:-?}"
  echo "passed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$GATE_PASS"
echo "GATE PASS — 0 CRITICAL${MAX_HIGH:+, HIGH $HIGH <= $MAX_HIGH}. Record: $GATE_PASS"
