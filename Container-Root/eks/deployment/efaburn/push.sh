#!/bin/bash

source .env

# Create registry if needed
REGISTRY_COUNT=$(aws ecr describe-repositories | grep ${IMAGE} | wc -l)
if [ "$REGISTRY_COUNT" == "0" ]; then
        CMD="aws ecr create-repository --repository-name ${IMAGE}"
	if [ ! "$VERBOSE" == "false" ]; then
		echo "$CMD"
	fi
	eval "$CMD"
fi

# Login to registry
echo "Logging in to $REGISTRY ..."
CMD="aws ecr get-login-password | docker login --username AWS --password-stdin $REGISTRY"
if [ ! "$VERBOSE" == false ]; then
	echo "$CMD"
fi
eval "$CMD"

CMD="docker image push ${REGISTRY}${IMAGE}${TAG}"
if [ ! "$VERBOSE" == false ]; then
	echo "$CMD"
fi
eval "$CMD"

