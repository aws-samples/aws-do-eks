#!/bin/bash

source .env

ext=cpu
if [ ! "$1" == "" ]; then
	        ext=$1
fi

# Build Docker image
docker image build ${BUILD_OPTS} -t ${REGISTRY}${IMAGE}${TAG}-$ext -f Dockerfile-$ext .

