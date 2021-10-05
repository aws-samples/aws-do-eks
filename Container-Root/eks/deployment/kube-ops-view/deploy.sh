#!/bin/bash

# Install kube-ops-view following instructions here:
# https://codeberg.org/hjacobs/kube-ops-view
# Please note: This deployment is provided here for convenience only.
#              It has its own license which is different than aws-do-eks.
#              Please comply with the terms of the kube-ops-view license
#              when using this deployment.

git clone https://codeberg.org/hjacobs/kube-ops-view.git

cd kube-ops-view 

kubectl apply -k deploy

kubectl get pods

kubectl get services

echo ""
echo "When kube-ops-view pods are Running, execute port-forward.sh to access the UI."
echo ""
 
