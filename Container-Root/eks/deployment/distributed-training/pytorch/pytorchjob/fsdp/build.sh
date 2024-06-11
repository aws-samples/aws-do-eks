#!/bin/bash

. .env


if [ "$DOCKERFILE_EXT" == "efa.dlc" ]; then
	./login.sh 763104351884.dkr.ecr.us-west-2.amazonaws.com
fi

export DOCKER_BUILDKIT=1
#docker build --no-cache --progress=plain --build-arg="MODEL_NAME=$MODEL_NAME" -t ${REGISTRY}${IMAGE}${TAG} -f Dockerfile.$DOCKERFILE_EXT .
docker build --progress=plain --build-arg="MODEL_NAME=$MODEL_NAME" -t ${REGISTRY}${IMAGE}${TAG} -f Dockerfile.$DOCKERFILE_EXT .

