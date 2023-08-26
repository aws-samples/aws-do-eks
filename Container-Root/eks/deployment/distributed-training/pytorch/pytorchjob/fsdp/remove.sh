#!/bin/bash

pushd ../../../../kubeflow/training-operator/
./remove.sh
popd

./generate.sh

kubectl delete -f ./etcd.yaml

