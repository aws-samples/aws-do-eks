#!/bin/bash

source .env

export CMD="kubectl -n ${NAMESPACE} cp -f \$(kubectl get pods | grep aiperf-sweep | cut -d ' ' -f 1):/tmp/run-bundle/summary.json ./sweep-summary.json"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi

eval "${CMD}"

export CMD="cat ./sweep-summary.json"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi

eval "${CMD}"
