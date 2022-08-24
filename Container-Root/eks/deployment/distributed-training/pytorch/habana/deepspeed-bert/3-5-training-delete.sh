#!/bin/bash

echo ""
echo "Deleting deepspeed-bert pods ..."
kubectl delete -f deepspeed-bert.yaml
sleep 3
kubectl get pods | grep deepspeed-bert
