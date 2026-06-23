#!/bin/bash

source .env

export CMD="kubectl -n ${NAMESPACE} logs -f \$(kubectl get pods | grep aiperf-sweep | cut -d ' ' -f 1)"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi

eval "${CMD}"
