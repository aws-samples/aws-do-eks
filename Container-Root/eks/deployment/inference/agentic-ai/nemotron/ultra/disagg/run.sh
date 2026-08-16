#!/bin/bash

source .env

if [ "${MANIFEST_TYPE}" == "" ]; then
	export MANIFEST_TYPE=deployment
fi

# KV_LEASE_DURATION lands inside the JSON of --kv-transfer-config, so an .env that predates
# it renders "kv_lease_duration":} and vLLM dies on the argument. Default it here too.
if [ "${KV_LEASE_DURATION}" == "" ]; then
	export KV_LEASE_DURATION=300
fi

cat ${MANIFEST_TYPE}.yaml-template | envsubst > ${MANIFEST_TYPE}.yaml
export CMD="kubectl apply -f ./${MANIFEST_TYPE}.yaml"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "$CMD"

# Verify: list everything this deployment created (empty until pods schedule)
kubectl -n ${NAMESPACE} get deploy,lws,dgd,svc,pods -l app.kubernetes.io/part-of=${DEPLOYMENT_NAME} 2>/dev/null
