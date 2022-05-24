#!/bin/bash

# Optional Prometheus / Grafana stack for monitoring of Karpenter metrics.

# Source eks.conf
if [ -f ./eks.conf ]; then
        . ./eks.conf
elif [ -f /eks/eks.conf ]; then
        . /eks/eks.conf
elif [ -f ../../eks.conf ]; then
        . ../../eks.conf
else
        echo ""
        echo "Error: Could not locate eks.conf"
fi

if [ "$CLUSTER_KARPENTER_VERSION" == "" ]; then
        echo ""
else
	helm repo add grafana-charts https://grafana.github.io/helm-charts
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update

	kubectl create namespace monitoring

	curl -fsSL https://karpenter.sh/"${CLUSTER_KARPENTER_VERSION}"/getting-started/getting-started-with-eksctl/prometheus-values.yaml | tee prometheus-values.yaml
	helm install --namespace monitoring prometheus prometheus-community/prometheus --values prometheus-values.yaml

	curl -fsSL https://karpenter.sh/"${CLUSTER_KARPENTER_VERSION}"/getting-started/getting-started-with-eksctl/grafana-values.yaml | tee grafana-values.yaml
	helm install --namespace monitoring grafana grafana-charts/grafana --values grafana-values.yaml
fi

