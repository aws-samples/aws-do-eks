#!/bin/bash

source .env

echo ""
echo "Generating etcd manifest ..."

cat etcd.yaml-template | envsubst > etcd.yaml

#cat etcd.yaml

echo ""
echo "Generating PyTorchJob manifest ..."

cat fsdp.yaml-template | envsubst > fsdp.yaml

#cat fsdp.yaml

echo "Done."
echo ""

