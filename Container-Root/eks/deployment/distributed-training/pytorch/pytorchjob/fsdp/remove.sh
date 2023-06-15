#!/bin/bash

pushd ../../../../kubeflow/training-operator/
./remove.sh
popd

pushd ../../../../etcd/
./remove.sh
popd

