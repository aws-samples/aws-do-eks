#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

source .env

# Create registry if needed
REGISTRY_COUNT=$(aws ecr describe-repositories | grep \"${IMAGE}\" | wc -l)
if [ "$REGISTRY_COUNT" == "0" ]; then
	aws ecr create-repository --repository-name ${IMAGE}
fi

# Login to registry
./login.sh

docker image push ${REGISTRY}${IMAGE}${TAG}

docker image tag ${REGISTRY}${IMAGE}${TAG} ${REGISTRY}${IMAGE}:latest

docker image push ${REGISTRY}${IMAGE}:latest

