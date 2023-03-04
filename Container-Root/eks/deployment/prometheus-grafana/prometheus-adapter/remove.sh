#!/bin/bash

# Reference: https://github.com/kubernetes-sigs/prometheus-adapter/tree/master/deploy

pushd prometheus-adapter/deploy

kubens monitoring

kubectl delete -f ./manifests

kubens default

kubectl delete ns monitoring

popd


