#!/bin/bash

source .env

echo ""
echo "Generating PyTorchJob manifests ..."

cat mnist-gloo.yaml-template | envsubst > mnist-gloo.yaml

cat mnist-nccl.yaml-template | envsubst > mnist-nccl.yaml

cat mnist-mpi.yaml-template | envsubst > mnist-mpi.yaml

echo "Done."
echo ""

