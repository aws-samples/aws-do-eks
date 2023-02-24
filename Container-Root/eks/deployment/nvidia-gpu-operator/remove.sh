#!/bin/bash

# Reference: https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/getting-started.html#uninstall

helm delete -n gpu-operator $(helm list -n gpu-operator | grep gpu-operator | awk '{print $1}')

