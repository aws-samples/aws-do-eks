#!/bin/bash

source .env

export MODE=-it

echo "Testing ${IMAGE} ..."

if [ "$TO" == "docker" ]; then

    CMD="docker container run ${RUN_OPTS} ${CONTAINER_NAME}-test ${MODE} --rm ${NETWORK} ${PORT_MAP} ${VOL_MAP} ${REGISTRY}${IMAGE}${TAG} sh -c 'for t in \$(ls /test*.sh); do echo Running test \$t; \$t; done;'"

elif [ "$TO" == "kubernetes" ]; then

    CMD="kubectl exec -it $(kubectl get pods | grep ${CONTAINER} | cut -d ' ' -f 1) -- sh -c 'for t in \$(ls /test*.sh); do echo Running test \$t; \$t; done;'"

else
    echo "Target orchestrator $TO not supported"
fi

if [ ! "$verbose" == "false" ]; then
    echo "$CMD"
fi

eval "$CMD"

