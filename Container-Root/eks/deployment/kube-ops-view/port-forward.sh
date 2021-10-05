#!/bin/bash

# Port forward the kube-ops-view service

kubectl port-forward service/kube-ops-view 8080:80

echo ""
echo "Visit http://localhost:8080 to see the kube-ops-view UI"
echo ""
