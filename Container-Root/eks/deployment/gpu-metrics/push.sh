#!/bin/bash

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

# Push Docker image
docker push ${REGISTRY}eks-cloudwatch-agent
