#/bin/bash

pushd ..
export CLUSTER_NAME=$(./eks-name.sh)
popd

export REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')

OIDC_PROVIDER_URL=$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} --query "cluster.identity.oidc.issuer" --output text)

OIDC_PROVIDER_ID=$(echo $OIDC_PROVIDER_URL | cut -d '/' -f 5)

IAM_OIDC_PROVIDER=$(aws iam list-open-id-connect-providers | grep ${OIDC_PROVIDER_ID})

if [ "$IAM_OIDC_PROVIDER" == "" ]; then
	echo "Associating IAM OIDC Provider with cluster ${CLUSTER_NAME} ..."
	eksctl utils associate-iam-oidc-provider --cluster ${CLUSTER_NAME} --approve
else
	echo "IAM OIDC Provider $IAM_OIDC_PROVIDER is already associated with cluster $CLUSTER_NAME"
fi

