#!/bin/bash

echo ""
echo "Deploying AWS Loab Balancer Controller to $CLUSTER_NAME ..."

source ../../eks.conf

# Prerequisites
pushd ..
./set-iam-oidc-provider.sh
popd
./set-iam-role.sh

# Install cert-manager to inject certificate configuration into the webhooks
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.1.1/cert-manager.yaml
echo "Wait 30 sec for cert-manager to start up"
sleep 30

cat ./v2_1_3_template.yaml | sed -e "s/your-cluster-name/$CLUSTER_NAME/g" > aws-load-balancer-controller.yaml

kubectl apply -f ./aws-load-balancer-controller.yaml

echo ""
echo "Done deploying AWS Load Balancer Controller"
echo ""
