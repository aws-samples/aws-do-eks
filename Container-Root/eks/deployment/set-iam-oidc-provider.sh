#/bin/bash

source ../eks.conf

OIDC_PROVIDER_URL=$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${CLUSTER_REGION} --query "cluster.identity.oidc.issuer" --output text)

OIDC_PROVIDER_ID=$(echo $OIDC_PROVIDER_URL | cut -d '/' -f 5)

IAM_OIDC_PROVIDER=$(aws iam list-open-id-connect-providers | grep ${OIDC_PROVIDER_ID})

if [ "$IAM_OIDC_PROVIDER" == "" ]; then
	echo "Associating IAM OIDC Provider with cluster ${CLUSTER_NAME} ..."
	eksctl utils associate-iam-oidc-provider --cluster ${CLUSTER_NAME} --approve
else
	echo "IAM OIDC Provider $IAM_OIDC_PROVIDER is already associated with cluster $CLUSTER_NAME"
fi

