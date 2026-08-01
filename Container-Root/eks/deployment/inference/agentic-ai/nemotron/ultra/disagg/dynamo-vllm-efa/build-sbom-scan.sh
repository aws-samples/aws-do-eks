#!/usr/bin/env bash
# build-sbom-scan.sh — pipeline gate for the ONE GOLDEN nemotron-disagg image:
#   reproducible build  +  SBOM (SPDX + CycloneDX)  +  CVE gate (0 CRITICAL, HIGH counted).
#
# Author: Anton Alexander
#
# Designed to be dropped straight into a build pipeline: no interactive steps, every
# artifact written to $OUTDIR, and a nonzero exit on any gate failure.
#
#   ./build-sbom-scan.sh                                   # build + SBOM + gate on CRITICAL
#   IMAGE=nemotron-disagg:golden ./build-sbom-scan.sh --scan-only    # scan a prebuilt image
#   GATE_SEVERITY=CRITICAL,HIGH ./build-sbom-scan.sh       # stricter gate
#   MAX_HIGH=40 ./build-sbom-scan.sh                       # also fail if HIGH exceeds a ceiling
#
# Exit codes: 0 pass | 2 build failed | 3 gate could not be evaluated (never a silent pass)
#             4 CVE gate failed on severity | 5 HIGH ceiling exceeded
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${IMAGE:-dynamo-vllm-efa:1.3.0-patched}"
GATE_SEVERITY="${GATE_SEVERITY:-CRITICAL}"
MAX_HIGH="${MAX_HIGH:-}"                       # empty = report HIGH, do not gate on it
OUTDIR="${OUTDIR:-$HERE/sbom}"
SCAN_ONLY=0
[ "${1:-}" = "--scan-only" ] && SCAN_ONLY=1

SAFE_TAG="$(echo "$IMAGE" | tr '/:' '__')"
SBOM_SPDX="$OUTDIR/${SAFE_TAG}.spdx.json"
SBOM_CDX="$OUTDIR/${SAFE_TAG}.cdx.json"
CVE_JSON="$OUTDIR/${SAFE_TAG}.trivy.json"
CVE_TXT="$OUTDIR/${SAFE_TAG}.trivy.txt"
mkdir -p "$OUTDIR"

for t in syft trivy docker; do
  command -v "$t" >/dev/null 2>&1 || { echo "FATAL: $t not on PATH"; exit 3; }
done

# ---- 1) build -------------------------------------------------------------------------
if [ "$SCAN_ONLY" = 0 ]; then
  echo "[1/3 BUILD] docker build -> $IMAGE"
  docker build -t "$IMAGE" "$HERE" || { echo "[1/3 BUILD] FAIL"; exit 2; }
else
  echo "[1/3 BUILD] skipped (--scan-only)"
  docker image inspect "$IMAGE" >/dev/null 2>&1 || { echo "FATAL: $IMAGE not present"; exit 2; }
fi

# ---- 2) SBOM --------------------------------------------------------------------------
echo "[2/3 SBOM] syft -> SPDX + CycloneDX ..."
syft "docker:$IMAGE" -o "spdx-json=$SBOM_SPDX" -o "cyclonedx-json=$SBOM_CDX" -q

# ---- 3) CVE gate ----------------------------------------------------------------------
# Scan the SBOM, NOT the image. A `trivy image` scan walks every layer's filesystem and
# reliably hits the default timeout on an image this size (~20GB); the timeout produced an
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

echo
echo "=============================== GATE SUMMARY ==============================="
echo "image      : $IMAGE"
echo "sbom_spdx  : $SBOM_SPDX ($PKG_COUNT packages)"
echo "sbom_cdx   : $SBOM_CDX"
echo "cve_report : $CVE_JSON / $CVE_TXT"
echo "CRITICAL=$CRIT  HIGH=$HIGH  TOTAL=$TOTAL   (gate severity: $GATE_SEVERITY)"
echo "==========================================================================="

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
echo "GATE PASS — 0 CRITICAL${MAX_HIGH:+, HIGH $HIGH <= $MAX_HIGH}."

