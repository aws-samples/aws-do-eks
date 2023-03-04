#!/bin/bash

# Reference: https://github.com/kubernetes-sigs/prometheus-adapter/tree/master/deploy

git clone https://github.com/kubernetes-sigs/prometheus-adapter.git
pushd prometheus-adapter/deploy

kubectl create namespace monitoring
kn monitoring

kubeclt apply -f ./manifests

kn default
popd


