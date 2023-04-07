#!/bin/bash

echo ""
echo "Traefik status:"

#echo ""
#echo "Helm chart:"
#helm list | grep traefik

echo ""
echo "Deployment:"
kubectl -n traefik get deployment | grep traefik

echo ""
echo "Pod:"
kubectl -n traefik get pods | grep traefik

echo ""
echo "Service:"
kubectl -n traefik get svc | grep traefik

echo ""
echo "Ingress class:"
kubectl get ingressclass | grep traefik

