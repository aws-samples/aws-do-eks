#!/bin/bash

# Remove RBAC resources

kubectl delete -f ./clusterrolebinding-training-operator-hpa-access.yaml

kubectl delete -f ./clusterrole-hpa-access.yaml

# Remove Kubeflow training operator

kubectl delete -k "github.com/kubeflow/trainer/manifests/overlays/standalone?ref=v1.7.0"

