#!/bin/bash

# Requires default storage class
# Ref: https://docs.nvidia.com/dynamo/kubernetes-deployment/deployment-guide/quickstart

export DYNAMO_NAMESPACE=dynamo-system
export DYNAMO_VERSION="1.2.0"

helm fetch https://helm.ngc.nvidia.com/nvidia/ai-dynamo/charts/dynamo-platform-${DYNAMO_VERSION}.tgz

helm upgrade --install dynamo-platform dynamo-platform-${DYNAMO_VERSION}.tgz --namespace "$DYNAMO_NAMESPACE"  --create-namespace -f values.yaml

