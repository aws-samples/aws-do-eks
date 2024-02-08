#!/bin/bash

kubectl apply -f https://raw.githubusercontent.com/kubeflow/mpi-operator/v0.4.0/deploy/v2beta1/mpi-operator.yaml

# Add lease permissions fot mpi-operator cluster role
kubectl apply -f ./clusterrole-mpi-operator.yaml
