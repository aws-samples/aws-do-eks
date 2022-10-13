#!/bin/bash

echo ""
echo "Prometheus status:"
kubectl get pods -A | grep prometheus

echo ""
echo "Grafana status:"
kubectl get pods -A | grep grafana

