#!/bin/bash

# This script removes the test fsx pod, pvc, and pv
# Please be aware that for dynamically provisioned FSx volumes
# when the PVC is removed, the FSx volume and its data is destroyed

kubectl delete -f ./test-fsx-pod.yaml

kubectl delete -f ./test-fsx-pvc-dynamic.yaml

#kubectl delete -f ./test-fsx-pvc-static.yaml

#kubectl delete -f ./test-fsx-pv-static.yaml

