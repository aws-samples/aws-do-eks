#!/bin/bash

. .env

#docker build --no-cache --progress=plain -t ${REGISTRY}${IMAGE}${TAG} -f Dockerfile .

if [ "$DOCKERFILE_EXT" == "efa.dlc" ]; then
	./login.sh 763104351884.dkr.ecr.us-west-2.amazonaws.com
fi

docker build --no-cache --progress=plain -t ${REGISTRY}${IMAGE}${TAG} -f Dockerfile.$DOCKERFILE_EXT .

