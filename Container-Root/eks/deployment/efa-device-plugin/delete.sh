#!/bin/bash

# Reference: https://raw.githubusercontent.com/aws-samples/aws-efa-eks/main/manifest/efa-k8s-device-plugin.yml

#kubectl delete -f ./efa-k8s-device-plugin.yaml

kubectl delete -f kubectl apply -f https://raw.githubusercontent.com/aws-samples/aws-efa-eks/main/manifest/efa-k8s-device-plugin.yml

