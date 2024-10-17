#!/bin/bash

# Deploy Prometheus and Grafana using helm
# helm version 3.8.2 required (newer versions may not work until AWS upgrades API version)

# add Prometheus Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# add Grafana Helm repo
helm repo add grafana https://grafana.github.io/helm-charts

# Deploy Prometheus
kubectl create namespace prometheus

helm install prometheus prometheus-community/prometheus \
    --namespace prometheus \
    --set alertmanager.persistence.storageClass="gp2" \
    --set server.persistentVolume.storageClass="gp2"


# Check Prometheus deployment
kubectl get all -n prometheus

# Deploy Grafana

mkdir -p ${HOME}/environment/grafana

cat << EoF > ${HOME}/environment/grafana/prometheus.yaml
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-server.prometheus.svc.cluster.local
      access: proxy
      isDefault: true
EoF

kubectl create namespace grafana

helm install grafana grafana/grafana \
    --namespace grafana \
    --set persistence.storageClassName="gp2" \
    --set persistence.enabled=true \
    --set adminPassword='Grafana@EKS' \
    --values ${HOME}/environment/grafana/prometheus.yaml \
    --set service.type=ClusterIP

# Check Grafana deployment
kubectl get all -n grafana


