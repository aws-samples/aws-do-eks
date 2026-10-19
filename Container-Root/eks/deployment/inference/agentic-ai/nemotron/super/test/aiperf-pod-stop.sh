#!/bin/bash

# Ref: https://github.com/iankoulski/do-aiperf

if [ -f ./.env ]; then source ./.env; fi

# Delete from the same namespace aiperf-pod-run.sh creates in (see the note there).
_NS_ARG=""
if [ "${NAMESPACE}" != "" ]; then _NS_ARG="-n ${NAMESPACE}"; fi

AIPERF_POD_NAME="${AIPERF_POD_NAME:-do-aiperf}"
echo "Removing ${AIPERF_POD_NAME} pod ..."

export CMD="kubectl ${_NS_ARG} delete pod ${AIPERF_POD_NAME}"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi

eval "${CMD}"
