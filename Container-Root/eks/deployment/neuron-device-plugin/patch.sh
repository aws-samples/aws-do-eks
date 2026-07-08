#!/bin/bash

# Add trn2.48xlarge and trn2n.48xlarge to node selector

kubectl patch daemonset neuron-device-plugin-daemonset -n kube-system --type=json -p='[{"op":"add","path":"/spec/template/spec/affinity/nodeAffinity/requiredDuringSchedulingIgnoredDuringExecution/nodeSelectorTerms/0/matchExpressions/0/values/-","value":"trn2.48xlarge"},{"op":"add","path":"/spec/template/spec/affinity/nodeAffinity/requiredDuringSchedulingIgnoredDuringExecution/nodeSelectorTerms/0/matchExpressions/0/values/-","value":"trn2n.48xlarge"}]'

