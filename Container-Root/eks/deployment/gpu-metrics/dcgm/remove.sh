#!/bin/bash

# Reference: https://developer.nvidia.com/blog/monitoring-gpus-in-kubernetes-with-dcgm/

echo ""
echo "Removing dgcm-exporter ..."


#helm delete gpu-helm-charts/dcgm-exporter

kubectl delete -f ./dcgm-exporter.yaml

