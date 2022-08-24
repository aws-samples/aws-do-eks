#!/bin/bash

echo ""
echo "Deleting mpijob-mnist pods ..."
kubectl delete -f mpijob-mnist.yaml
sleep 3
kubectl get pods | grep mnist
