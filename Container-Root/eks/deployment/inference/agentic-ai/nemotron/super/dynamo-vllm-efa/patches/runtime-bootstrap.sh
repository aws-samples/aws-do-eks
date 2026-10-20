#!/bin/bash
# Test-only runtime bootstrap for the Ray / PP>1 shapes (RUNTIME_BOOTSTRAP=1 in ../../agg/.env or
# ../../disagg/.env). run.sh publishes this folder as a ConfigMap that those templates mount at
# /opt/runtime-bootstrap; the vllm container then runs this as root at start and applies what
# ../Dockerfile.ray bakes at build time: ray[default]==2.55.1 (its step 2, `ray` mode only) and the
# NemotronH_Nano_VL_V2 SupportsPP patch (its step 3, both modes). The production path is the golden
# image built from ../Dockerfile.ray; this exists for a cluster that cannot pull one yet, and adds
# roughly 2-4 minutes to every pod start it runs in.
#
#   bash /opt/runtime-bootstrap/runtime-bootstrap.sh ray     # Ray-bootstrapped PP2 (lws, lws-2pp, lws-pp2)
#   bash /opt/runtime-bootstrap/runtime-bootstrap.sh patch   # operator-bootstrapped PP (dgd-grove, dgd-grove-pp2)
set -euo pipefail
MODE=${1:?ray|patch}
if [ "$(id -u)" != 0 ]; then
  echo "[runtime-bootstrap] FATAL: needs uid 0 (the image's vllm tree is root-owned); the template renders runAsUser: 0 only when RUNTIME_BOOTSTRAP=1" >&2
  exit 1
fi
if [ "${MODE}" = ray ]; then
  if python3 -c 'import ray' 2>/dev/null; then
    echo "[runtime-bootstrap] ray already importable, skipping pip"
  else
    echo "[runtime-bootstrap] pip install ray[default]==2.55.1 ..."
    pip install --no-cache-dir -q "ray[default]==2.55.1"
  fi
  python3 - <<'PY'
import importlib.metadata as m
assert m.version("ray") == "2.55.1", m.version("ray")
assert m.version("vllm").startswith("0.28"), "ray install drifted vllm off 0.28.x"
import ray  # import, not just metadata
print(f"[runtime-bootstrap] ray={m.version('ray')} OK, vllm={m.version('vllm')} intact")
PY
fi
VLLM_DIR="$(python3 -c 'import vllm, os; print(os.path.dirname(vllm.__file__))')"
if grep -q SupportsPP "${VLLM_DIR}/model_executor/models/nano_nemotron_vl.py"; then
  echo "[runtime-bootstrap] SupportsPP already present in nano_nemotron_vl.py, skipping patch"
else
  python3 "$(dirname "$0")/apply_pp_patch.py"
fi
echo "[runtime-bootstrap] done (${MODE})"
