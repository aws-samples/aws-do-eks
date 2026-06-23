#!/bin/bash

source .env

export CMD="kubectl -n ${NAMESPACE} delete pod \$(kubectl get pods | grep aiperf-sweep | cut -d ' ' -f 1)"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi

eval "${CMD}"
