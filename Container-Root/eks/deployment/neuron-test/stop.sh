#!/bin/bash

source .env

if [ "$TO" == "docker" ]; then
    CMD="docker container rm -f ${CONTAINER}"
elif [ "$TO" == "kubernetes" ]; then
    CMD="kubectl delete -f ./neuron-test.yaml"
else
    echo "Target orchestrator $TO not recognized"
fi

if [ ! "$verbose" == "false" ]; then
    echo "$CMD"
fi

eval "$CMD"

