#!/bin/bash

# Reference: https://developer.nvidia.com/blog/monitoring-gpus-in-kubernetes-with-dcgm/

echo ""
echo "Deploying dgcm-exporter ..."

#helm repo add gpu-helm-charts https://nvidia.github.io/gpu-monitoring-tools/helm-charts

#helm repo update

#helm install --generate-name gpu-helm-charts/dcgm-exporter

kubectl apply -f ./dcgm-exporter.yaml
