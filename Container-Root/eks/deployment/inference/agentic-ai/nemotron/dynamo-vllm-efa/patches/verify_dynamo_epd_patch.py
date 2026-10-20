#!/usr/bin/env python3
"""Prove the NemotronH Omni encode-worker patch (patches/0003-dynamo-encode-worker-nemotron-h-omni-1.5.0.dynamo.diff)
is applied to dynamo's vllm backend and loads: imports the patched modules and checks their markers. Run at build time
after the patch step (Dockerfile, DYNAMO_EPD_NEMOTRON_PATCH=1); exits non-zero on any missing marker."""
import inspect, json, os, tempfile

import dynamo.vllm.multimodal_handlers.encode_worker_handler as handler
import dynamo.vllm.multimodal_utils.encode_utils as encode_utils
import dynamo.vllm.multimodal_utils.model as model
import dynamo.vllm.multimodal_utils.prefill_worker_utils as prefill_utils

assert hasattr(model.ModelFamily, "NEMOTRON_H_OMNI"), "marker missing: ModelFamily.NEMOTRON_H_OMNI"
for arch in ("NemotronH_Omni_Reasoning_V3", "NemotronH_Super_Omni_Reasoning_V3", "NemotronH_Nano_VL_V2"):
    assert arch in model._FAMILY_ARCHITECTURES[model.ModelFamily.NEMOTRON_H_OMNI], f"marker missing: architecture {arch}"
assert "hf_overrides" in inspect.signature(model.load_vision_model).parameters, "marker missing: load_vision_model(hf_overrides=)"
assert "mm_encoder_only=True" in inspect.getsource(model.load_vision_model), "marker missing: encoder-only engine path"
assert callable(getattr(encode_utils, "get_nemotron_h_omni_image_features", None)), "marker missing: get_nemotron_h_omni_image_features"
assert "ModelFamily.NEMOTRON_H_OMNI" in inspect.getsource(encode_utils.encode_image_embeddings), "marker missing: encode branch"
assert "ModelFamily.NEMOTRON_H_OMNI" in inspect.getsource(encode_utils.get_encoder_components), "marker missing: components branch"
hs = open(handler.__file__).read()
assert 'hf_overrides=getattr(self.engine_args, "hf_overrides", None)' in hs, "marker missing: handler forwards hf_overrides"
assert "isinstance(embeddings, torch.Tensor)" in hs, "marker missing: handler list-aware post-processing"
ps = open(prefill_utils.__file__).read()
assert 'isinstance(mm_data["image"], list)' in ps and "isinstance(img, list)" in ps, "marker missing: PD-side list ingestion"
assert "ModelFamily.NEMOTRON_H_OMNI" in inspect.getsource(model.construct_mm_data), "marker missing: construct_mm_data branch"
with tempfile.TemporaryDirectory() as d:
    json.dump({"architectures": ["NemotronH_Omni_Reasoning_V3"]}, open(os.path.join(d, "config.json"), "w"))
    assert model.resolve_model_family(d) is model.ModelFamily.NEMOTRON_H_OMNI, "family resolution by config.json failed"
assert model.resolve_model_family("Qwen/Qwen2.5-VL-7B-Instruct") is model.ModelFamily.QWEN_VL, "Qwen-VL resolution regressed"
assert model.resolve_model_family("llava-hf/llava-1.5-7b-hf") is model.ModelFamily.LLAVA, "LLaVA resolution regressed"
from vllm.transformers_utils.processors.nano_nemotron_vl import DynamicResolutionImageTiler  # noqa: F401  (the stack() the encoder uses)
import vllm.model_executor.models.nano_nemotron_vl as nnvl
assert "num_patches = None if raw_num_patches is None else int(raw_num_patches)" in open(nnvl.__file__).read(), \
    "marker missing: vLLM nano_nemotron_vl image_embeds num_patches guard (patches/0004-*.vllm.diff)"
assert 'if (image_embeds := kwargs.pop("image_embeds", None)) is not None:' in open(nnvl.__file__).read(), \
    "marker missing: vLLM nano_nemotron_vl image_embeds presence test (patches/0004-*.vllm.diff hunk 2)"
print("[dynamo-epd] NemotronH Omni encode-worker patch applied: family registered, vLLM encoder-only loader + per-image features + list-aware PD ingestion present; vLLM image_embeds num_patches guard present")
