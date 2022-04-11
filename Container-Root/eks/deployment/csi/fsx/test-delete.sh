#!/bin/bash

# This script removes the test fsx pod, pvc, and pv
# Please be aware that for dynamically provisioned FSx volumes
# when the PVC is removed, the FSx volume and its data is destroyed

kubectl delete -f ./fsx-share-test.yaml

kubectl delete -f ./fsx-pvc-dynamic.yaml

#kubectl delete -f ./test-fsx-pvc-static.yaml

#kubectl delete -f ./test-fsx-pv-static.yaml

