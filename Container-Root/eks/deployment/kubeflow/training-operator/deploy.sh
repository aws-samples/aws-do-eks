#!/bin/bash

# Deploy Kubeflow training operator

kubectl apply -k "github.com/kubeflow/training-operator/manifests/overlays/standalone?ref=v1.5.0"


