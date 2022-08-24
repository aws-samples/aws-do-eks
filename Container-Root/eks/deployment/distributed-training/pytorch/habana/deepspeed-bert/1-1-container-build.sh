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

# Build Docker image
echo "Building image ${REGISTRY}habana-pytorch-efa ..."
docker image build -t ${REGISTRY}habana-pytorch-efa .

