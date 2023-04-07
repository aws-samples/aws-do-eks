#!/bin/bash

# Reference: https://keda.sh/docs/2.10/deploy/

helm repo add kedacore https://kedacore.github.io/charts
helm repo update
kubectl create namespace keda
helm install keda kedacore/keda --namespace keda

