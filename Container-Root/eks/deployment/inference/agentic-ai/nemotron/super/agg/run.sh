#!/bin/bash

source .env

if [ "${MANIFEST_TYPE}" == "" ]; then
	export MANIFEST_TYPE=deployment
fi

cat ${MANIFEST_TYPE}.yaml-template | envsubst > ${MANIFEST_TYPE}.yaml

# RUNTIME_BOOTSTRAP=1 (test-only, see .env): publish ../dynamo-vllm-efa/patches as the ConfigMap the
# Ray / PP>1 templates mount at /opt/runtime-bootstrap. Carries the part-of label so stop.sh's sweep
# removes it with everything else.
if [ "${RUNTIME_BOOTSTRAP_RAY_CMD}" != ":" ]; then
  kubectl -n ${NAMESPACE} create configmap ${DEPLOYMENT_NAME}-runtime-bootstrap \
    --from-file=runtime-bootstrap.sh=../dynamo-vllm-efa/patches/runtime-bootstrap.sh \
    --from-file=apply_pp_patch.py=../dynamo-vllm-efa/patches/apply_pp_patch.py \
    --dry-run=client -o yaml | kubectl label --local -f - app.kubernetes.io/part-of=${DEPLOYMENT_NAME} -o yaml | kubectl apply -f -
fi
export CMD="kubectl apply -f ./${MANIFEST_TYPE}.yaml"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "$CMD"

# Verify: list everything this deployment created (empty until pods schedule)
kubectl -n ${NAMESPACE} get deploy,lws,dgd,svc,pods -l app.kubernetes.io/part-of=${DEPLOYMENT_NAME} 2>/dev/null

