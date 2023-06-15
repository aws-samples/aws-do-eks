#!/bin/bash

source .env

echo ""
echo "Generating PyTorchJob manifest ..."

cat fsdp.yaml-template | envsubst > fsdp.yaml

cat fsdp.yaml

echo "Done."
echo ""

