#!/bin/bash

# Remove kube-ops-view:
# Reference: https://codeberg.org/hjacobs/kube-ops-view

cd kube-ops-view 

kubectl delete -k deploy

kubectl get pods

kubectl get services

cd ..

# Optionally remove cloned kube-ops-view repo
#rm -rf kube-ops-view
