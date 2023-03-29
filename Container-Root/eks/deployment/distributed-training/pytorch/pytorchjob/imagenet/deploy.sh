#!/bin/bash

pushd ../../../../kubeflow/training-operator/
./deploy.sh
popd

pushd ../../../../etcd/
./deploy.sh
popd

