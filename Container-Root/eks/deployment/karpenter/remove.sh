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
	export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
	helm uninstall karpenter --namespace karpenter
	aws iam detach-role-policy --role-name="${CLUSTER_NAME}-karpenter" --policy-arn="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/KarpenterControllerPolicy-${CLUSTER_NAME}"
	aws iam delete-policy --policy-arn="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/KarpenterControllerPolicy-${CLUSTER_NAME}"
	aws iam delete-role --role-name="${CLUSTER_NAME}-karpenter"
	aws cloudformation delete-stack --stack-name "Karpenter-${CLUSTER_NAME}"
	aws ec2 describe-launch-templates \
    	| jq -r ".LaunchTemplates[].LaunchTemplateName" \
    	| grep -i "Karpenter-${CLUSTER_NAME}" \
    	| xargs -I{} aws ec2 delete-launch-template --launch-template-name {}
fi
