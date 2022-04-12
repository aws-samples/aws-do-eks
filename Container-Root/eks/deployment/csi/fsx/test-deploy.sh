#!/bin/bash

# This script creates an FSx volume using the fsx storage class with a volume claim
# Please note the volume will take a while (up to 10 min) to provision
# A pod is started and mounts the volume claim under /data
# You can exec into the pod and explore the volume
# Please be aware that when the PVC is deleted, 
# the volume and any data stored on it is deleted as well.

# Alternatively you can configure and apply the static manifests below

#kubectl apply -f ./test-fsx-pv-static.yaml
#kubectl apply -f ./test-fsx-pvc-static.yaml

kubectl apply -f ./fsx-pvc-dynamic.yaml

kubectl describe pvc fsx-claim

kubectl apply -f ./fsx-share-test.yaml

#kubectl exec -it test-fsx-pod -- bash
