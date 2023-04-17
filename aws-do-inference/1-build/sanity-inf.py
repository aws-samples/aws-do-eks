import torch, torch_neuron
import torch.nn as nn
from time import time

# Define minimalistic PyTorch model class
class mymodel(nn.Module):
    def __init__(self):
        super(mymodel, self).__init__()

    def forward(self, inputs):
        a = inputs[0]
        b = inputs[1]
        return torch.matmul(a,b)

# Create example model inputs required for tracing
inputs = (torch.randn((5000,100), dtype=torch.float32), torch.randn((100,5000), dtype=torch.float32))

# Instantiate instance of model
mymodel = mymodel()

# Trace the model, returning a Neuron-compiled version
nmod = torch.neuron.trace(mymodel, example_inputs=[inputs], minimum_segment_size=1)

# Save Neuron-compiled model -> can be loaded at a later time using torch.jit.load()
nmod.save("neuron_model.pt")

print("\nAttempting inference using Neuron-compiled model")
for _ in range(10):
    start = time()
    _ = nmod(inputs)
    print(f"latency: {time()-start:.3f}s")

