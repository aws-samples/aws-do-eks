#!/bin/bash

source .env

# Build Docker image
#CMD="docker image build ${BUILD_OPTS} -t ${REGISTRY}${IMAGE}${TAG} ."
CMD="docker image build ${BUILD_OPTS} -t ${REGISTRY}${IMAGE}${TAG} -f Dockerfile.public ."

echo "$CMD"

eval "$CMD"

