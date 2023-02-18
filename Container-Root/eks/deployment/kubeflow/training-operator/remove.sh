#!/bin/bash

# Remove Kubeflow training operator

kubectl delete -k "github.com/kubeflow/training-operator/manifests/overlays/standalone?ref=v1.5.0"


