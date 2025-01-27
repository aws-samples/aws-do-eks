#!/bin/bash

# Reference: https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/docs/install.md

kubectl delete -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.39"

