#!/bin/bash

source ../../eks.conf

echo ""
echo "Deploying Kubernetes Dashboard to $CLUSTER_NAME ..."
echo ""

# Prerequisites
pushd ..
./deploy-metrics-server.sh
popd

# Deploy Kubernetes Dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.5/aio/deploy/recommended.yaml

kubectl apply -f ./eks-admin-service-account.yaml

echo ""
echo "Done deploying Kubernetes Dashboard"
echo ""
