#!/usr/bin/env python3
"""Prove the NIXL pull-path pipeline-parallel backport (patches/0002-nixl-pull-path-pipeline-parallel-0.28.0.vllm.diff,
vllm-project/vllm#53360 onto vLLM 0.28.0) is applied and loads: imports the patched package and checks its markers.
Run at build time after the patch step (Dockerfile, NIXL_PP_PATCH=1); exits non-zero on any missing marker."""
import vllm.distributed.kv_transfer.kv_connector.v1.nixl.base_worker as bw
import vllm.distributed.kv_transfer.kv_connector.v1.nixl.pull_worker as pw
import vllm.distributed.kv_transfer.kv_connector.v1.nixl.push_worker as pushw
import vllm.distributed.kv_transfer.kv_connector.v1.nixl.metadata as md
import vllm.distributed.kv_transfer.kv_connector.v1.nixl.connector as cn

assert getattr(pw.NixlPullConnectorWorker, "_supports_consumer_pp", False) is True, \
    "marker missing: pull worker does not declare consumer-PP support"
assert getattr(pw.NixlPullConnectorWorker, "_supports_pp_hma", False) is True, \
    "marker missing: pull worker does not declare PP+HMA support"
assert getattr(pushw.NixlPushConnectorWorker, "_supports_pp_hma", True) is False, \
    "marker wrong: push worker must keep PP+HMA unsupported"
assert md.NIXL_CONNECTOR_VERSION >= 10, f"connector v{md.NIXL_CONNECTOR_VERSION} < 10: patch not applied"
_fields = set(getattr(md.NixlAgentMetadata, "__annotations__", {}) or {})
_md_src = open(md.__file__).read()
for f in ("pp_rank", "pp_size", "registered_layer_names", "region_members"):
    assert f in _fields or f"{f}:" in _md_src, f"marker missing: NixlAgentMetadata.{f}"
src = open(bw.__file__).read()
for marker in ("_add_pp_remote_agent", "_local_region_indices_if_overlapping", "_shard_desc_slots", "_handshake_complete"):
    assert marker in src, f"marker missing in base_worker.py: {marker}"
assert hasattr(bw.NixlBaseConnectorWorker, "_representative_stage"), "marker missing: _representative_stage"
assert cn.NixlConnector is cn.NixlPullConnector, "NixlConnector is not the pull connector"
print(f"[nixl-pp] vllm#53360 backport applied; connector v{md.NIXL_CONNECTOR_VERSION}; PP>1 pull-path disagg (incl. hybrid-Mamba, symmetric PPxPP) enabled")
