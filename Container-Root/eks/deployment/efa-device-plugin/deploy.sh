#!/bin/bash

# It is recommended to deploy the efa device plugin using the official helm chart
# Reference: https://github.com/aws/eks-charts/tree/master/stable/aws-efa-k8s-device-plugin
helm repo add eks https://aws.github.io/eks-charts
helm install efa eks/aws-efa-k8s-device-plugin -n kube-system

# Old reference: https://raw.githubusercontent.com/aws-samples/aws-efa-eks/main/manifest/efa-k8s-device-plugin.yml
#kubectl apply -f ./efa-k8s-device-plugin.yaml
#kubectl apply -f https://raw.githubusercontent.com/aws-samples/aws-efa-eks/main/manifest/efa-k8s-device-plugin.yml
