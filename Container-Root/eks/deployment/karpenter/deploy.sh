#!/bin/bash

# Source eks.conf
if [ -f ./eks.conf ]; then
	. ./eks.conf
elif [ -f /eks/eks.conf ]; then
	. /eks/eks.conf
elif [ -f ../../eks.conf ]; then
	. ../../eks.conf
else
	echo ""
	echo "Error: Could not locate eks.conf"
fi

if [ "$CLUSTER_NAME" == "" ]; then
	echo ""
else
	# Create KarpenterNode IAM Role
	TEMPOUT=$(mktemp)
	curl -fsSL https://karpenter.sh/"${CLUSTER_KARPENTER_VERSION}"/getting-started/getting-started-with-eksctl/cloudformation.yaml  > $TEMPOUT \
	&& aws cloudformation deploy \
  	--stack-name "Karpenter-${CLUSTER_NAME}" \
  	--template-file "${TEMPOUT}" \
  	--capabilities CAPABILITY_NAMED_IAM \
  	--parameter-overrides "ClusterName=${CLUSTER_NAME}"
	
	# Grant access to instances with IAM Role to connect to the cluster
	export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
	eksctl create iamidentitymapping \
  	--username system:node:{{EC2PrivateDNSName}} \
  	--cluster "${CLUSTER_NAME}" \
  	--arn "arn:aws:iam::${AWS_ACCOUNT_ID}:role/KarpenterNodeRole-${CLUSTER_NAME}" \
  	--group system:bootstrappers \
  	--group system:nodes

	# Create KarpenterController IAM Role
	eksctl create iamserviceaccount \
  	--cluster "${CLUSTER_NAME}" --name karpenter --namespace karpenter \
  	--role-name "${CLUSTER_NAME}-karpenter" \
  	--attach-policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/KarpenterControllerPolicy-${CLUSTER_NAME}" \
  	--role-only \
  	--approve

	export KARPENTER_IAM_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${CLUSTER_NAME}-karpenter"

	# Create EC2 Spot Service Linked Role
	# If the role has already been successfully created, you will see:
	# An error occurred (InvalidInput) when calling the CreateServiceLinkedRole operation: Service role name AWSServiceRoleForEC2Spot has been taken in this account, please try a different suffix.
	aws iam create-service-linked-role --aws-service-name spot.amazonaws.com || true

	# Install Karpenter Helm Chart
	helm repo add karpenter https://charts.karpenter.sh/
	helm repo update

	# Install Karpenter
	export CLUSTER_ENDPOINT="$(aws eks describe-cluster --name ${CLUSTER_NAME} --query "cluster.endpoint" --output text)"
	helm upgrade --install --namespace karpenter --create-namespace \
	karpenter karpenter/karpenter \
  	--version ${CLUSTER_KARPENTER_VERSION} \
  	--set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${KARPENTER_IAM_ROLE_ARN} \
  	--set clusterName=${CLUSTER_NAME} \
  	--set clusterEndpoint=${CLUSTER_ENDPOINT} \
  	--set aws.defaultInstanceProfile=KarpenterNodeInstanceProfile-${CLUSTER_NAME} \
 	--wait # for the defaulting webhook to install before creating a Provisioner

fi

