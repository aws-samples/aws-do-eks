#!/bin/bash

# Source karpenter.conf
source ./karpenter.conf

if [ "$CLUSTER_NAME" == "" ]; then
	echo ""
	echo "Could not determine cluster name. Please check ./karpenter.conf"
	echo ""
else
	# Reference: https://karpenter.sh/v0.37/getting-started/getting-started-with-karpenter/	
	echo ""
	echo "Creating Karpenter NodeRole, ControllerPolicy, InterruptionQueue, InterruptionQueuePolicy, and Rules using CloudFormation ..."
	# Create Karpenter NodeRole, ControllerPolicy, InterruptionQueue, InterruptionQueuePolicy, and Rules
	curl -fsSL https://raw.githubusercontent.com/aws/karpenter-provider-aws/"v${KARPENTER_VERSION}"/website/content/en/preview/getting-started/getting-started-with-karpenter/cloudformation.yaml  > $TEMPOUT \
	&& aws cloudformation deploy \
  	--stack-name "Karpenter-${CLUSTER_NAME}" \
  	--template-file "${TEMPOUT}" \
  	--capabilities CAPABILITY_NAMED_IAM \
  	--parameter-overrides "ClusterName=${CLUSTER_NAME}"

	echo ""
	echo "Creating IAM Identity Mapping so Karpenter instances can connect to the cluster ..."
	# Grant access to instances with IAM Role to connect to the cluster
	eksctl create iamidentitymapping \
  	--username system:node:{{EC2PrivateDNSName}} \
  	--cluster "${CLUSTER_NAME}" \
  	--arn "arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:role/KarpenterNodeRole-${CLUSTER_NAME}" \
  	--group system:bootstrappers \
  	--group system:nodes

	echo ""
	echo "Creating KarpenterController IAM Role ..."
	# Create KarpenterController IAM Service Account and IAM Role
	eksctl create iamserviceaccount \
  	--cluster "${CLUSTER_NAME}" --name karpenter --namespace karpenter \
  	--role-name "${CLUSTER_NAME}-karpenter-role" \
  	--attach-policy-arn "arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:policy/KarpenterControllerPolicy-${CLUSTER_NAME}" \
	--role-only \
  	--approve
  	

	export CLUSTER_ENDPOINT="$(aws eks describe-cluster --name ${CLUSTER_NAME} --query "cluster.endpoint" --output text)"
	export KARPENTER_IAM_ROLE_ARN="arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:role/${CLUSTER_NAME}-karpenter-role"

	echo ""
	echo "CLUSTER_ENDPOINT=$CLUSTER_ENDPOINT"
	echo "KARPENTER_IAM_ROLE_ARN=$KARPENTER_IAM_ROLE_ARN"
	echo ""

	# Create EC2 Spot Service Linked Role
	echo ""
	echo "Enabling spot ..."
	echo ""
	echo "It is ok to see an error here if the service linked role already exists"
	aws iam create-service-linked-role --aws-service-name spot.amazonaws.com || true
	echo ""

	# Install Karpenter from Helm Chart
	echo ""
	echo "It is ok to see an error here if helm is not logged in to public.ecr.aws"
	helm registry logout public.ecr.aws || true
	
	echo ""
	echo "Installing Karpenter using helm ..."
	helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter --version "${KARPENTER_VERSION}" --namespace "${KARPENTER_NAMESPACE}" --create-namespace \
	  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=${KARPENTER_IAM_ROLE_ARN}" \
	  --set "settings.clusterName=${CLUSTER_NAME}" \
	  --set "settings.interruptionQueue=${CLUSTER_NAME}" \
	  --set controller.resources.requests.cpu=1 \
	  --set controller.resources.requests.memory=1Gi \
	  --set controller.resources.limits.cpu=1 \
	  --set controller.resources.limits.memory=1Gi \
	  --wait

	echo "done installing Karpenter..."
	kubectl -n $KARPENTER_NAMESPACE get pods
fi

