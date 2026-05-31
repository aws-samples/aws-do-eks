#!/bin/bash

# Leader Worker Set Uninstall
# Ref: https://lws.sigs.k8s.io/docs/installation/

VERSION=v0.7.0
kubectl delete --server-side -f https://github.com/kubernetes-sigs/lws/releases/download/$VERSION/manifests.yaml

