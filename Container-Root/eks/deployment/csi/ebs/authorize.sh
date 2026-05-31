#!/bin/bash

# 1. Get cluster name and ensure there is an OIDC Provider
pushd /eks
CLUSTER_NAME=$(./eks-name.sh)
popd
OIDC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text | cut -d'/' -f5)

if [ ! "${OIDC_ID}" == "" ]; then

	# 2. Create the IAM role with the AWS-managed policy
	eksctl create iamserviceaccount \
	  --name ebs-csi-controller-sa \
	  --namespace kube-system \
	  --cluster ${CLUSTER_NAME} \
	  --role-name AmazonEKS_EBS_CSI_DriverRole_${CLUSTER_NAME} \
	  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
	  --approve \
	  --override-existing-serviceaccounts

	# 3. Restart the controller
	kubectl rollout restart deployment ebs-csi-controller -n kube-system

else
	echo "OIDC provider not found for cluster $CLUSTER_NAME"
fi
