#!/bin/bash

source .env

# Build Docker image
CMD="docker image build ${BUILD_OPTS} -t ${REGISTRY}${IMAGE}${TAG} ."

if [ ! "$VERBOSE" == "false" ]; then
       echo "$CMD"
fi

eval "$CMD"

