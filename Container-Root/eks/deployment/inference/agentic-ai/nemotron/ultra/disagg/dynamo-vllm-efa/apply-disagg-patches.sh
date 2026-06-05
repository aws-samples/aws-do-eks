#!/usr/bin/env bash
#Author: Anton Alexander
set -euo pipefail
SP="$(python3 -c 'import vllm,os;print(os.path.dirname(vllm.__file__))')"
cd "$(dirname "$SP")"
for p in /tmp/dp/pr-disagg-*.patch; do echo "[disagg] dry-run $(basename "$p")"; patch -p1 --fuzz=0 --dry-run < "$p"; done
for p in /tmp/dp/pr-disagg-*.patch; do echo "[disagg] apply   $(basename "$p")"; patch -p1 --fuzz=0 < "$p"; done
grep -q is_kv_consumer "$SP/model_executor/models/config.py"
# Static verification of the rebased PR43935 logic (no GPU/weights needed):
# drive MambaModelConfig.verify_and_update_config with synthetic configs and
# assert the disagg-critical outputs (mamba_cache_mode + mamba_block_size).
python3 - <<'PY'
from types import SimpleNamespace as NS
from vllm.model_executor.models.config import MambaModelConfig
MAX_LEN, BLOCK = 131072, 16
def run(kv_role=None, is_kv_consumer=False, mode="align"):
    v = NS(
        model_config=NS(supports_mamba_prefix_caching=False, max_model_len=MAX_LEN,
                        architecture="NemotronHForCausalLM"),
        cache_config=NS(enable_prefix_caching=False, mamba_cache_mode=mode,
                        mamba_block_size=None, block_size=BLOCK),
        scheduler_config=NS(disable_hybrid_kv_cache_manager=False, enable_chunked_prefill=True),
        kv_transfer_config=(None if kv_role is None else NS(kv_role=kv_role, is_kv_consumer=is_kv_consumer)),
        speculative_config=None)
    MambaModelConfig.verify_and_update_config(v)
    return v.cache_config.mamba_cache_mode, v.cache_config.mamba_block_size
assert run(None, False, "align") == ("none", MAX_LEN), run(None, False, "align")
assert run("kv_producer", False, "align") == ("align", BLOCK), run("kv_producer", False, "align")
assert run("kv_consumer", True, "align") == ("align", MAX_LEN), run("kv_consumer", True, "align")
assert run("kv_both", False, "align") == ("align", MAX_LEN), run("kv_both", False, "align")
assert run("kv_consumer", True, "none")[0] == "align", run("kv_consumer", True, "none")
print("[disagg] PR43935 rebase synthetic-config verification: PASS (none/producer/consumer/kv_both)")
PY
python3 - <<'PY'
import py_compile, os
SP = os.path.dirname(__import__("vllm").__file__)
for f in ["v1/core/sched/scheduler.py","config/vllm.py","v1/worker/mamba_utils.py","v1/worker/gpu_model_runner.py","model_executor/models/config.py"]:
    py_compile.compile(os.path.join(SP, f), doraise=True)
print("[disagg] py_compile OK")
PY
python3 -m compileall -q "$SP/v1/core/sched/scheduler.py" "$SP/config/vllm.py" "$SP/v1/worker/mamba_utils.py" "$SP/v1/worker/gpu_model_runner.py" "$SP/model_executor/models/config.py" || true
# restore ownership to the runtime user so patched files + fresh .pyc are owned by dynamo
chown -R dynamo:dynamo "$SP/v1/core/sched" "$SP/config" "$SP/v1/worker" "$SP/model_executor/models" 2>/dev/null || true
echo "[disagg] PR#42522 + PR#43935 applied + verified (precompiled + chowned)"
