#!/bin/bash

./set-iam-role.sh

pushd ../..
CLUSTER_NAME=$(./eks-name.sh)
popd

set -e

# Reference: https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html

export ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

# 1. Create IAM policy if it does not exist

export POLICY_NAME=AWSLoadBalancerControllerIAMPolicy
export POLICY_ARN="arn:aws:iam::${ACCOUNT}:policy/${POLICY_NAME}"

POLICY=$(aws iam get-policy --policy-arn=$POLICY_ARN)
POLICY_EXISTS=$?

if [ ! "$POLICY_EXISTS" == "0" ]; then
	echo "Creating policy $POLICY_NAME ..."

	curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/install/iam_policy.json

	aws iam create-policy \
    	--policy-name $POLICY_NAME \
    	--policy-document file://iam_policy.json
else
	echo "Policy $POLICY_NAME already exists ..."
fi

# 2. Create IAM role if it does not exist

export ROLE_NAME=AmazonEKSLoadBalancerControllerRole
ROLE=$(aws iam get-role --role-name=${ROLE_NAME})
ROLE_EXISTS=$?

if [ ! "$ROLE_EXISTS" == "0" ]; then
	echo "Creating role $ROLE_NAME ..."

	eksctl create iamserviceaccount \
  	--cluster=${CLUSTER_NAME} \
  	--namespace=kube-system \
  	--name=aws-load-balancer-controller \
  	--role-name ${ROLE_NAME} \
  	--attach-policy-arn=${POLICY_ARN} \
  	--approve
else
	echo "Role $ROLE_NAME already exists ..."
fi

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


