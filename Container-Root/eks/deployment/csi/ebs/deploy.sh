#!/bin/bash

# Reference: https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/docs/install.md

./authorize.sh

kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.60"

