#!/bin/bash

echo ""
echo "Deploying EKS Cluster Autoscaler to $CLUSTER_NAME ..."

source ../../eks.conf

# Prerequisites
pushd ..
./set-iam-oidc-provider.sh
popd 
./set-iam-role.sh

#curl -o cluster-autoscaler-autodiscover.yaml https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

cat ./cluster-autoscaler-template.yaml | sed -e "s/<CLUSTER_AUTOSCALER_IMAGE_TAG>/$CLUSTER_AUTOSCALER_IMAGE_TAG/g" | sed -e "s/<YOUR CLUSTER NAME>/$CLUSTER_NAME/g" > cluster-autoscaler.yaml

kubectl apply -f ./cluster-autoscaler.yaml

echo ""
echo "Done deploying EKS Cluster Autoscaler"
echo ""

