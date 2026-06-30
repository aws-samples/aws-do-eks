#!/usr/bin/env bash
# =============================================================================
# build-sbom-scan.sh - first-deliverable gate for the Nemotron-3 disagg image:
#   rebuildable patched image  +  SBOM  +  0 CRITICAL CVEs.
#
# Author: Anton Alexander
#
# Three stages, fail-loud:
#   1. BUILD  : docker build the efa-official recipe (ENABLE_DISAGG_PATCHES=1)
#   2. SBOM   : syft -> SPDX-JSON + CycloneDX-JSON (the provenance artifact)
#   3. GATE   : trivy image scan; FAIL if any CRITICAL CVE (severity gate).
#
# Per the patch-method decision (3-LLM unanimous: bake, not ConfigMap), the
# SBOM/CVE scan reflects EXACTLY what runs because the patches are baked in.
#
# Usage:
#   ./build-sbom-scan.sh                       # build + scan, gate on CRITICAL
#   IMAGE=dynamo-vllm-efa:disagg-1.2.0 ./build-sbom-scan.sh --scan-only   # scan a prebuilt image
#   GATE_SEVERITY=CRITICAL,HIGH ./build-sbom-scan.sh             # stricter gate
# =============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

# ---- config (override via env) ---------------------------------------------
IMAGE="${IMAGE:-dynamo-vllm-efa:disagg-1.2.0}"
VLLM_EFA_IMAGE="${VLLM_EFA_IMAGE:-nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.2.0-efa}"
ENABLE_DISAGG_PATCHES="${ENABLE_DISAGG_PATCHES:-1}"
GATE_SEVERITY="${GATE_SEVERITY:-CRITICAL}"     # fail the build on these severities
VEX_FILE="${VEX_FILE:-$HERE/vex.openvex.json}"   # OpenVEX justifications (e.g. CVE-2026-48746)
OUTDIR="${OUTDIR:-$HERE/sbom}"
SCAN_ONLY=0
[ "${1:-}" = "--scan-only" ] && SCAN_ONLY=1

mkdir -p "$OUTDIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
SAFE_TAG="$(echo "$IMAGE" | tr '/:' '__')"
SBOM_SPDX="$OUTDIR/${SAFE_TAG}.spdx.json"
SBOM_CDX="$OUTDIR/${SAFE_TAG}.cyclonedx.json"
CVE_JSON="$OUTDIR/${SAFE_TAG}.trivy.json"
CVE_TXT="$OUTDIR/${SAFE_TAG}.trivy.txt"
SUMMARY="$OUTDIR/${SAFE_TAG}.gate-summary.txt"

echo "=============================================================="
echo "[gate] image            : $IMAGE"
echo "[gate] base             : $VLLM_EFA_IMAGE"
echo "[gate] disagg patches   : $ENABLE_DISAGG_PATCHES"
echo "[gate] fail-on severity : $GATE_SEVERITY"
echo "[gate] artifacts        : $OUTDIR"
echo "[gate] utc              : $STAMP"
echo "=============================================================="

# ---- stage 1: BUILD --------------------------------------------------------
if [ "$SCAN_ONLY" = "0" ]; then
  echo "[1/3 BUILD] docker build ..."
  DOCKER_BUILDKIT=1 docker build \
    --build-arg VLLM_EFA_IMAGE="$VLLM_EFA_IMAGE" \
    --build-arg ENABLE_DISAGG_PATCHES="$ENABLE_DISAGG_PATCHES" \
    -t "$IMAGE" \
    -f "$HERE/Dockerfile" "$HERE"
  echo "[1/3 BUILD] OK -> $IMAGE"
else
  echo "[1/3 BUILD] --scan-only: skipping build, scanning $IMAGE as-is"
  docker image inspect "$IMAGE" >/dev/null
fi

# ---- stage 2: SBOM ---------------------------------------------------------
echo "[2/3 SBOM] syft -> SPDX + CycloneDX ..."
syft "docker:$IMAGE" -o "spdx-json=$SBOM_SPDX" -o "cyclonedx-json=$SBOM_CDX" -q
PKG_COUNT="$(python3 -c "import json;print(len(json.load(open('$SBOM_SPDX')).get('packages',[])))" 2>/dev/null || echo '?')"
echo "[2/3 SBOM] OK -> $SBOM_SPDX ($PKG_COUNT packages), $SBOM_CDX"

# ---- stage 3: CVE GATE -----------------------------------------------------
# Scan the CycloneDX SBOM we just produced, NOT the 8GB image. Re-analyzing the
# image makes trivy walk every layer's filesystem and reliably hits the default
# 5-minute deadline ("context deadline exceeded") on a 8GB CUDA image — which
# previously left CVE_JSON unwritten and silently passed the gate. Scanning the
# SBOM is filesystem-free (seconds) and covers the exact same package set syft
# already enumerated. --timeout is belt-and-suspenders.
VEX_ARG=""
[ -s "$VEX_FILE" ] && VEX_ARG="--vex $VEX_FILE" && echo "[3/3 GATE] applying VEX: $VEX_FILE"
echo "[3/3 GATE] trivy SBOM scan ($SBOM_CDX) ..."
trivy sbom --scanners vuln --timeout 30m $VEX_ARG --format json  -o "$CVE_JSON" "$SBOM_CDX" || true
trivy sbom --scanners vuln --timeout 30m $VEX_ARG --severity "$GATE_SEVERITY" --format table -o "$CVE_TXT" "$SBOM_CDX" || true

# FAIL-LOUD: a missing/empty CVE report is a gate FAILURE, never a silent pass.
# (The old code let a trivy timeout -> absent JSON -> empty count -> `[ "" -gt 0 ]`
#  integer-error -> fall through to PASS. That false-pass is the bug we are fixing.)
if [ ! -s "$CVE_JSON" ]; then
  echo "[3/3 GATE] FAIL — trivy produced no CVE report ($CVE_JSON missing/empty)."
  echo "[3/3 GATE]        the scan errored (see stderr above); refusing to claim 0 CRITICAL."
  exit 3
fi

# Count gating-severity vulns straight from the JSON (source of truth).
# python exits NONZERO on any parse problem so the gate fails loud, not silent.
read -r CRIT_COUNT GATE_COUNT <<<"$(python3 - "$CVE_JSON" "$GATE_SEVERITY" <<'PY'
import json,sys
try:
    data=json.load(open(sys.argv[1]))
except Exception as e:
    sys.stderr.write("trivy JSON parse failed: %s\n" % e); sys.exit(1)
gate=set(s.strip().upper() for s in sys.argv[2].split(','))
crit=0; gated=0
for r in data.get("Results",[]) or []:
    for v in (r.get("Vulnerabilities") or []):
        sev=(v.get("Severity") or "").upper()
        if sev=="CRITICAL": crit+=1
        if sev in gate: gated+=1
print(crit, gated)
PY
)"

# Guard: counts MUST be integers. Anything else means the parse path broke —
# fail rather than let `[ "$GATE_COUNT" -gt 0 ]` error-out into a false PASS.
if ! [[ "$CRIT_COUNT" =~ ^[0-9]+$ ]] || ! [[ "$GATE_COUNT" =~ ^[0-9]+$ ]]; then
  echo "[3/3 GATE] FAIL — could not parse CVE counts (crit='$CRIT_COUNT' gated='$GATE_COUNT')."
  exit 3
fi

{
  echo "Nemotron-3 disagg image — SBOM + CVE gate summary"
  echo "image      : $IMAGE"
  echo "base       : $VLLM_EFA_IMAGE"
  echo "patches    : ENABLE_DISAGG_PATCHES=$ENABLE_DISAGG_PATCHES"
  echo "utc        : $STAMP"
  echo "sbom_spdx  : $SBOM_SPDX ($PKG_COUNT packages)"
  echo "sbom_cdx   : $SBOM_CDX"
  echo "cve_report : $CVE_JSON"
  echo "gate_sev   : $GATE_SEVERITY"
  echo "critical   : $CRIT_COUNT"
  echo "gated_total: $GATE_COUNT"
} | tee "$SUMMARY"

echo "--------------------------------------------------------------"
if [ "$GATE_COUNT" -gt 0 ]; then
  echo "[3/3 GATE] FAIL — $GATE_COUNT vuln(s) at severity {$GATE_SEVERITY} (CRITICAL=$CRIT_COUNT)"
  echo "[3/3 GATE] see $CVE_TXT for the gating list"
  exit 2
fi
echo "[3/3 GATE] PASS — 0 vulns at severity {$GATE_SEVERITY} (CRITICAL=$CRIT_COUNT)"
echo "[done] SBOM + CVE-gate artifacts in $OUTDIR"
