#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

if [ -f /aws-do-eks/.env ]; then
    pushd /aws-do-eks
else
    pushd ../../../../
fi
source .env
popd

if [ -z $REGISTRY ]; then
    echo 'REGISTRY not defined in .env file. Exiting.'
    exit
else
    echo 'Using' $REGISTRY
fi

# Build Docker image
docker image build -t ${REGISTRY}pytorch-efa .
