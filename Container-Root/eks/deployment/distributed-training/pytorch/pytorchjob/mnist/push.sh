#!/bin/bash

function usage(){
        echo ""
        echo "Usage: ${0} [tag]"
        echo "tag - Docker image tag. Matches Dockerfile suffix (e.g. mpi)"
        echo ""
}

source .env

# Create registry if it does not exist
REGISTRY_COUNT=$(aws ecr describe-repositories | grep ${IMAGE} | wc -l)
if [ "$REGISTRY_COUNT" == "0" ]; then
	echo ""
	echo "Creating repository ${IMAGE} ..."
	aws ecr create-repository --repository-name ${IMAGE}
fi

# Login to registry
echo ""
echo "Logging in to $REGISTRY ..."
aws ecr get-login-password | docker login --username AWS --password-stdin $REGISTRY

# Push image
echo ""

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
else
        if [ "$1" == "" ]; then
		echo "Pushing image ${REGISTRY}${IMAGE}:latest"
		docker image push ${REGISTRY}${IMAGE}:latest
        else
		echo "Pushing image ${REGISTRY}${IMAGE}:$1"
		docker image push ${REGISTRY}${IMAGE}:$1
        fi
fi
