#!/bin/bash

source .env

# Build Docker image
CMD="docker image build ${BUILD_OPTS} -t ${REGISTRY}${IMAGE}${TAG} ."

echo "$CMD"

eval "$CMD"

