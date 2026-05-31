#!/bin/bash

# Leader Worker Set
# Ref: https://github.com/kubernetes-sigs/lws

VERSION=v0.7.0
kubectl apply --server-side -f https://github.com/kubernetes-sigs/lws/releases/download/$VERSION/manifests.yaml

