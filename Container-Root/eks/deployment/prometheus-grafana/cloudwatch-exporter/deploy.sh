#!/bin/bash

# Reference: https://learnk8s.io/autoscaling-apps-kubernetes
# Reference: https://github.com/prometheus/cloudwatch_exporter
# Reference: https://hub.docker.com/r/prom/cloudwatch-exporter/tags

# Reference: https://artifacthub.io/packages/helm

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring
kubens monitoring

helm install prometheus-cloudwatch-exporter prometheus-community/prometheus-cloudwatch-exporter

