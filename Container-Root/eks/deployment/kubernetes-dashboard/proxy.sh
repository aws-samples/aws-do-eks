#!/bin/bash

echo ""

kubectl proxy

echo "Kubernetes Dashboard Proxy URL:"
echo "http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#!/login"
echo ""
