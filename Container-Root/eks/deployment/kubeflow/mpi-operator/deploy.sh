#!/bin/bash

# Ref: https://github.com/kubeflow/mpi-operator

kubectl apply --server-side -f https://raw.githubusercontent.com/kubeflow/mpi-operator/v0.8.0/deploy/v2beta1/mpi-operator.yaml

# Add lease permissions for mpi-operator cluster role
#kubectl apply -f ./clusterrole-mpi-operator.yaml
