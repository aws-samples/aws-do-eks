#!/bin/bash

source .env

if [ "$TO" == "docker" ]; then

    CMD="docker ps -a | grep ${CONTAINER}"

elif [ "$TO" == "kubernetes" ]; then

    CMD="kubectl get pods | grep -E 'STATUS|neuron-test'"

else
    echo "Target orchestrator $TO not recognized"
fi

if [ ! "$verbose" == "false" ]; then
    echo "$CMD"
fi

eval "$CMD"

