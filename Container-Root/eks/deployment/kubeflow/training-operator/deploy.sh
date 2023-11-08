#!/bin/bash

# Deploy Kubeflow training operator

kubectl apply -k "github.com/kubeflow/training-operator/manifests/overlays/standalone?ref=v1.7.0"

# Configure RBAC resources

kubectl apply -f ./clusterrole-hpa-access.yaml

kubectl apply -f ./clusterrolebinding-training-operator-hpa-access.yaml

