#!/bin/bash

source .env

CMD="docker image build ${BUILD_OPTS} -t ${REGISTRY}${IMAGE}${TAG} ."
echo "$CMD"

# Build Docker image
eval "$CMD"

