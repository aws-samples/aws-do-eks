#!/bin/bash

# It is recommended to install and remove the eks device plugin using the official EKS efa helm chart
# Reference: https://github.com/aws/eks-charts/tree/master/stable/aws-efa-k8s-device-plugin
helm uninstall efa

# Old reference: https://raw.githubusercontent.com/aws-samples/aws-efa-eks/main/manifest/efa-k8s-device-plugin.yml
#kubectl delete -f ./efa-k8s-device-plugin.yaml
#kubectl delete -f https://raw.githubusercontent.com/aws-samples/aws-efa-eks/main/manifest/efa-k8s-device-plugin.yml

