#!/bin/bash

# Ref: https://docs.nvidia.com/dynamo/kubernetes-deployment/deployment-guide

kubectl delete dgd --all -A

export DYNAMO_NAMESPACE=dynamo-system

helm delete dynamo-platform -n $DYNAMO_NAMESPACE

kubectl get crd | grep "dynamo.*nvidia.com"

kubectl get crd | grep "dynamo.*nvidia.com" | awk '{print $1}' | xargs kubectl delete crd


