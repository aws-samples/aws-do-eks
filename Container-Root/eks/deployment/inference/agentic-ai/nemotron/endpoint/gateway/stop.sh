#!/bin/bash

source .env
export RATE_LIMIT_BURST=$(( RATE_LIMIT_RPS * 2 ))

# 1. Delete the declared resources.
cat keygate.yaml-template | envsubst > keygate.yaml
export CMD="kubectl delete -f ./keygate.yaml --ignore-not-found"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "$CMD"

# 2. Sweep by label: the key Secret (secret-sync.sh labels it) and anything left from an edited render. Deleting the
#    key Secret is what revokes the key for every attendee who copied it.
export CMD="kubectl -n ${NAMESPACE} delete deploy,svc,ingress,cm,secret,pods --selector app.kubernetes.io/part-of=${GATEWAY_NAME} --ignore-not-found"
if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "$CMD"

# 3. The TLS certificate Secret is kept by default: Let's Encrypt limits duplicate certificates per week, so a
#    redeploy reuses it. DELETE_TLS=1 ./stop.sh removes it too.
if [ "${DELETE_TLS}" == "1" ]; then
  kubectl -n ${NAMESPACE} delete secret ${GATEWAY_NAME}-tls --ignore-not-found
fi

kubectl -n ${NAMESPACE} wait --for=delete pods --selector app.kubernetes.io/part-of=${GATEWAY_NAME} --timeout=120s 2>/dev/null
echo ""
echo "Verifying teardown (the following should be empty):"
kubectl -n ${NAMESPACE} get deploy,svc,ingress,cm,secret,pods --selector app.kubernetes.io/part-of=${GATEWAY_NAME} 2>/dev/null
echo "Done."
