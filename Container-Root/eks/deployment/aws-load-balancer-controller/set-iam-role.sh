#!/bin/bash

pushd ../..
export CLUSTER_NAME=$(./eks-name.sh)
popd

#Get account id
account=$(aws sts get-caller-identity | jq -r '.Account')

#Create aws-load-balancer-controller policy if one does not exist
IAM_POLICY=$(aws iam list-policies --no-paginate | grep PolicyName | grep AWSLoadBalancerControllerIAMPolicy)

if [ "$IAM_POLICY" == "" ]; then
	echo "Creating AWS Load Balancer Controller IAM Policy ..."
	json_out=$(aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://aws-lb-controller-policy.json)
	POLICY_ARN=$(echo $json_out | jq -r '.Policy.Arn')
	echo "POLICY_ARN=$POLICY_ARN"
else
	echo "IAM Policy $IAM_POLICY already exists"
fi

# Create service account aws-load-balancer-controller with attached policy if it does not exist
output=$(eksctl get iamserviceaccount --cluster $CLUSTER_NAME --output json)
clean_out=$(echo ${output##*[} )
json_out="[ $clean_out"
IAM_SA_NAMES=$(echo $json_out | jq -r '.[].metadata.name')
IAM_SA_NAME=$(echo $IAM_SA_NAMES | grep aws-load-balancer-controller) 

if [ "$IAM_SA_NAME" == "" ]; then
        echo "Creating IAM Service Account aws-load-balancer-controller ..."
        eksctl create iamserviceaccount --cluster=$CLUSTER_NAME --namespace=kube-system --name=aws-load-balancer-controller \
                                        --attach-policy-arn=arn:aws:iam::${account}:policy/AWSLoadBalancerControllerIAMPolicy \
					--override-existing-serviceaccounts --approve 
else
        echo "IAM Service Account $IAM_SA_NAME already exists"
fi

