#!/bin/bash

# Reference: https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/getting-started.html

# Add helm repo
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia && helm repo update

# Install in gpu-operator namespace
helm install --wait --generate-name -n gpu-operator --create-namespace --set driver.enabled=false --set toolkit-enabled=false --set migManager.enabled=false --set psp.enabled=false --set mig.strategy=single --set nfd.enabled=true nvidia/gpu-operator

