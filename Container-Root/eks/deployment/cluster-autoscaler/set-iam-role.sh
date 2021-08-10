#!/bin/bash

source ../../eks.conf

# Create cluster autoscaler policy if it does not exist
IAM_POLICY=$(aws iam list-policies --no-paginate | grep PolicyName | grep AmazonEKSClusterAutoscalerPolicy)

if [ "$IAM_POLICY" == "" ]; then
	echo "Creating Cluster Autoscaler IAM Policy ..."
	json_out=$(aws iam create-policy --policy-name AmazonEKSClusterAutoscalerPolicy --policy-document file://cluster-autoscaler-policy.json)
	arn=$(echo $json_out | jq '.Policy.Arn')
	POLICY_ARN=$(echo $arn | sed -e 's/\"//g')
	echo "POLICY_ARN=$POLICY_ARN"
else
	echo "IAM Policy $IAM_POLICY alreqady exists"
fi

# Create service account cluster-autoscaler with attached policy if it does not exist
output=$(eksctl get iamserviceaccount --cluster $CLUSTER_NAME --output json)
clean_out=$(echo ${output##*[} )
json_out="[ $clean_out"
IAM_SA_NAMES=$(echo $json_out | jq -r '.[].metadata.name')
IAM_SA_NAME=$(echo $IAM_SA_NAMES | grep cluster-autoscaler) 

if [ "$IAM_SA_NAME" == "" ]; then
	echo "Creating IAM Service Account cluster-autoscaler ..."
	eksctl create iamserviceaccount --cluster=$CLUSTER_NAME --namespace=kube-system --name=cluster-autoscaler \
					--attach-policy-arn=$POLICY_ARN --override-existing-serviceaccounts --approve 
else
	echo "IAM Service Account $IAM_SA_NAME already exists"
fi


