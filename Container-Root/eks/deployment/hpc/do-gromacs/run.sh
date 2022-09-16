#!/bin/bash

source .env

if [ "$TO" == "docker" ]; then

	if [ -z "$1" ]; then
		MODE=-d
	else
		MODE=-it
	fi 

	docker container run ${RUN_OPTS} ${CONTAINER_NAME} ${MODE} ${NETWORK} ${PORT_MAP} ${VOL_MAP} ${REGISTRY}${IMAGE}${TAG} $@

elif [ "$TO" == "kubernetes" ]; then
	generate_kubernetes_manifests
	kubectl apply -f to/kubernetes/app
else
	echo ""
	echo "Unknown Target Orchestrator $TO"
fi
echo ""

