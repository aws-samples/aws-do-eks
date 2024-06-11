#!/bin/bash

set -e

# Reference: https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html

# This script removes the controller and leaves the policy and role in place

helm repo add eks https://aws.github.io/eks-charts

helm repo update

helm uninstall aws-load-balancer-controller 

