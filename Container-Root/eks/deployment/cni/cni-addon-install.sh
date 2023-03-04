#!/bin/bash

. /eks/eks.conf

set -e

# Reference: https://docs.aws.amazon.com/eks/latest/userguide/managing-vpc-cni.html#vpc-cni-latest-available-version

# Save configuraion of current addon

mkdir -p /wd/conf/cni
kubectl get daemonset aws-node -n kube-system -o yaml > /wd/conf/cni/aws-k8s-cni-old.yaml

# Create add-on

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
aws eks create-addon --cluster-name $CLUSTER_NAME --addon-name vpc-cni --addon-version $CLUSTER_VPC_CNI_VERSION \
	    --service-account-role-arn arn:aws:iam::${ACCOUNT}:role/AmazonEKSVPCCNIRole


