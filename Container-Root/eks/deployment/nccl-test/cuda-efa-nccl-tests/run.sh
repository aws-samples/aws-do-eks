#!/bin/bash

source .env


if [ -z "$MODE" ]; then
	if [ -z "$1" ]; then
		MODE=-d
	else
		MODE=-it
	fi
fi	

docker container run ${RUN_OPTS} ${CONTAINER_NAME} ${MODE} ${NETWORK} ${PORT_MAP} ${VOL_MAP} ${REGISTRY}${IMAGE}${TAG} $@

