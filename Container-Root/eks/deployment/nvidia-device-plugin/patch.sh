#!/bin/bash

# Ref: https://github.com/NVIDIA/k8s-device-plugin

# Patch daemonset so that plugin pods are only running on nodes labeled with nvidia.com/gpu.present=true
kubectl patch daemonset nvidia-device-plugin-daemonset -n kube-system --type=merge -p '{"spec":{"template":{"spec":{"nodeSelector":{"nvidia.com/gpu.present":"true"}}}}}'

