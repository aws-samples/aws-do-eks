#!/bin/bash

source .env

cat aiperf-sweep.yaml-template | envsubst > aiperf-sweep.yaml

export CMD="kubectl apply -f ./aiperf-sweep.yaml"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi

eval "${CMD}"
