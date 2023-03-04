#!/bin/bash

# Reference: https://docs.aws.amazon.com/eks/latest/userguide/managing-vpc-cni.html
# See for compatible versions

kubectl describe daemonset aws-node --namespace kube-system | grep amazon-k8s-cni: | cut -d : -f 3

