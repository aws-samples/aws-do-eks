#!/bin/bash

kubectl apply -f ./example-pv-static.yaml

kubectl apply -f ./example-pvc-static.yaml

kubectl get pvc fsx-claim

kubectl apply -f ./example-pod.yaml

#kubectl exec -it fsx-app -- tail -f /data/out.txt
