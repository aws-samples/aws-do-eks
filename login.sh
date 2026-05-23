#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

source ./.env

# Login to container registry
if [ "$1" == "" ]; then
	echo "Logging in to $REGISTRY ..."
	aws ecr get-login-password | docker login --username AWS --password-stdin $REGISTRY
elif [ "$1" == "public" ]; then
	echo "Logging in to public.ecr.aws ..."
	aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws
else 
	echo "Logging in to $1 ..."
	docker login $1
fi

