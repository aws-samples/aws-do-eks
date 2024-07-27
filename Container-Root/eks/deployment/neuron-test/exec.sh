#!/bin/bash

source .env

if [ "$1" == "" ]; then
	CMDLN=/bin/bash
else
	CMDLN=$@
fi

if [ "$TO" == "docker" ]; then

    CMD="docker container exec -it ${CONTAINER} $CMDLN"

elif [ "$TO" == "kubernetes" ]; then
    
    CMD="kubectl exec -it $(kubectl get pods | grep ${CONTAINER} | cut -d ' ' -f 1) -- $CMDLN "

else
    echo "Target orchestrator $TO not supported"
fi

if [ ! "$verbose" == "false" ]; then
    echo "$CMD"
fi

eval "$CMD"

