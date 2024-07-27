#!/bin/bash

source .env


if [ "$TO" == "docker" ]; then

    if [ -z "$MODE" ]; then
	if [ -z "$1" ]; then
		MODE=-d
	else
		MODE=-it
	fi
    fi
    CMD="docker container run ${RUN_OPTS} ${CONTAINER_NAME} ${MODE} ${NETWORK} ${PORT_MAP} ${VOL_MAP} ${REGISTRY}${IMAGE}${TAG} $@"

elif [ "$TO" == "kubernetes" ]; then     

    cat ./neuron-test.yaml-template | envsubst > ./neuron-test.yaml
    CMD="kubectl apply -f ./neuron-test.yaml"
fi

if [ ! "$verbose" == "false" ]; then
    echo "$CMD"
fi

eval "$CMD"

