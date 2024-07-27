#!/bin/bash

source .env

if [ "$TO" == "docker" ]; then
    CMD="docker container logs -f ${CONTAINER}"
elif [ "$TO" == "kubernetes" ]; then
    CMD="kubectl logs -f $(kubectl get pods | grep ${CONTAINER} | cut -d ' ' -f 1)"
else
    echo "Target orchestrator $TO not recognized"
fi

if [ ! "$verbose" == "false" ]; then
    echo "$CMD"
fi

eval "$CMD"

