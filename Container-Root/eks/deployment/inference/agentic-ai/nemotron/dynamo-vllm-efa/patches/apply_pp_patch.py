#!/usr/bin/env python3
"""Apply SupportsPP + make_empty_intermediate_tensors patch to NemotronH_Nano_VL_V2."""
import importlib.util, pathlib, textwrap

site = importlib.util.find_spec("vllm").submodule_search_locations[0]
fp = pathlib.Path(site) / "model_executor" / "models" / "nano_nemotron_vl.py"
src = fp.read_text()

# (a) Add SupportsPP import
assert "SupportsPP" not in src, "SupportsPP already present"
src = src.replace(
    "from vllm.model_executor.models.interfaces import (\n    HasInnerState,\n    IsHybrid,",
    "from vllm.model_executor.models.interfaces import (\n    HasInnerState,\n    IsHybrid,\n    SupportsPP,",
)
assert "SupportsPP," in src, "import insertion failed"

# (b) Add SupportsPP to class bases
src = src.replace(
    "nn.Module, HasInnerState, IsHybrid, SupportsMultiModal, SupportsMultiModalPruning",
    "nn.Module, HasInnerState, IsHybrid, SupportsPP, SupportsMultiModal, SupportsMultiModalPruning",
)

# (c) Add make_empty_intermediate_tensors method after hf_to_vllm_mapper
METHOD = '''
    def make_empty_intermediate_tensors(
        self, batch_size: int, dtype: "torch.dtype", device: "torch.device"
    ) -> "IntermediateTensors":
        """Create empty intermediate tensors for non-first PP ranks.

        Must match the keys returned by NemotronHModel.forward() on
        intermediate ranks: {"hidden_states", "residual"}.
        """
        from vllm.sequence import IntermediateTensors
        hs = self.language_model.config.hidden_size
        return IntermediateTensors({
            "hidden_states": torch.zeros(batch_size, hs, dtype=dtype, device=device),
            "residual": torch.zeros(batch_size, hs, dtype=dtype, device=device),
        })

'''

anchor = '        },\n    )\n\n    @classmethod\n    def get_placeholder_str'
assert anchor in src, "anchor not found in nano_nemotron_vl.py"
src = src.replace(anchor, '        },\n    )\n' + METHOD + '    @classmethod\n    def get_placeholder_str')

fp.write_text(src)
print(f"[patch] wrote {fp} ({len(src)} bytes)")

# Verify
from importlib import reload
import vllm.model_executor.models.nano_nemotron_vl as mod
reload(mod)
from vllm.model_executor.models.nano_nemotron_vl import NemotronH_Nano_VL_V2
from vllm.model_executor.models.interfaces import SupportsPP
assert SupportsPP in NemotronH_Nano_VL_V2.__mro__, "SupportsPP not in MRO"
assert hasattr(NemotronH_Nano_VL_V2, 'make_empty_intermediate_tensors'), \
    "make_empty_intermediate_tensors not found"
print("[patch] NemotronH_Nano_VL_V2: SupportsPP + make_empty_intermediate_tensors OK")
