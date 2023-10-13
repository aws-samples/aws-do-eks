#!/bin/bash

pushd ../../../../kubeflow/training-operator/
./deploy.sh
popd

./generate.sh

kubectl apply -f ./etcd.yaml

