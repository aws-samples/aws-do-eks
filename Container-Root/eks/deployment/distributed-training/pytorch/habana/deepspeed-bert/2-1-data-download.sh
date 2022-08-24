#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

if [ -f /aws-do-eks/.env ]; then
    pushd /aws-do-eks
else
    pushd ../../../../../../../
fi
source .env
popd

echo ""
echo "Generating pod manifest ..."
cat efs-get-data.yaml.template | sed -e "s@\${REGISTRY}@${REGISTRY}@g" > efs-get-data.yaml

echo ""
echo "Creating efs-data-prep pod ..."
kubectl apply -f ../../../../csi/efs/efs-pvc.yaml
kubectl apply -f efs-get-data.yaml
sleep 3
kubectl get pods | grep data-prep

