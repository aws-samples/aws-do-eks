#!/bin/bash

source /eks/eks.conf

set -e

# Reference: https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html

# 1. Create IAM policy

curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

# 2. Create IAM role
export ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
eksctl create iamserviceaccount \
  --cluster=${CLUSTER_NAME} \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::${ACCOUNT}:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# 3. Install controller via helm

helm repo add eks https://aws.github.io/eks-charts

helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=${CLUSTER_NAME} \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller 

# 4 Verify installation

kubectl get deployment -n kube-system aws-load-balancer-controller


