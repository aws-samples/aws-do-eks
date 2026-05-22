#!/bin/bash

# Reference: https://github.com/NVIDIA/topograph

git clone https://github.com/NVIDIA/topograph.git

pushd topograph

helm install topograph charts/topograph \
  --namespace topograph --create-namespace \
  --set global.provider.name=aws

popd

#helm install topograph \
#  oci://ghcr.io/nvidia/topograph/topograph \
#  --namespace topograph --create-namespace \
#  --set global.provider.name=aws


