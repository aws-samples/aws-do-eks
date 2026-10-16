#!/bin/bash

curl -LO https://github.com/kvaps/kubectl-node-shell/raw/master/kubectl-node_shell
chmod +x ./kubectl-node_shell

# Add tolerations for all NoSchedule taints (GPU, Neuron, etc.)
sed -i 's|{ "effect": "NoExecute",       "operator": "Exists" }|{ "effect": "NoExecute",       "operator": "Exists" },\n      { "effect": "NoSchedule",      "operator": "Exists" }|' ./kubectl-node_shell

mv ./kubectl-node_shell /usr/local/bin/kubectl-node_shell
