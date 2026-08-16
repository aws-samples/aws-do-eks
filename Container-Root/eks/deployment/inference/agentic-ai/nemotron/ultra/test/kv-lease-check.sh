#!/bin/bash

# Report whether a disagg run served requests on KV blocks the prefill side had freed.
# See the header of kv-lease-check.py for the two log lines this looks for and why the
# second one does not fail the request.
#
# Usage: ./kv-lease-check.sh                        # live: every prefill Pod of the deployment
#        ./kv-lease-check.sh <prefill-worker.log>   # a log you already saved
#
# Live mode is read-only - it runs `kubectl logs` and nothing else - and writes each
# Pod's log under ./kv-lease-check-logs/ so a finding stays reproducible after teardown.
# Exits 1 when a lease expired unread, so it can gate a benchmark.

source .env

if [ "$1" == "" ]; then

  export PREFILL_PODS=$(kubectl -n ${NAMESPACE} get pods -o name | grep "${DEPLOYMENT_NAME}" | grep -i prefill | sed 's|^pod/||')

  if [ "${PREFILL_PODS}" == "" ]; then
    echo "No prefill Pod matching '${DEPLOYMENT_NAME}' and 'prefill' in namespace ${NAMESPACE}."
    echo "Check NAMESPACE and DEPLOYMENT_NAME in .env, or pass a saved log:"
    echo "  ./kv-lease-check.sh <prefill-worker.log>"
    exit 1
  fi

  export LOG_DIR=./kv-lease-check-logs
  mkdir -p ${LOG_DIR}
  export LOGS=""

  for POD in ${PREFILL_PODS}; do
    export CMD="kubectl -n ${NAMESPACE} logs ${POD} > ${LOG_DIR}/${POD}.log"
    if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
    eval "${CMD}"
    export LOGS="${LOGS} ${LOG_DIR}/${POD}.log"
  done

else
  export LOGS="$@"
fi

export CMD="python3 ./kv-lease-check.py ${LOGS}"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi

eval "${CMD}"
