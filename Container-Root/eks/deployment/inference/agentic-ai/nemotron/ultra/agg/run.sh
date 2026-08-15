#!/bin/bash

source .env

if [ "${MANIFEST_TYPE}" == "" ]; then
	export MANIFEST_TYPE=deployment
fi

export CMD=""

case "${MANIFEST_TYPE}" in
        deployment|lws|lws-ep|dgd)
                cat ${MANIFEST_TYPE}.yaml-template | envsubst > ${MANIFEST_TYPE}.yaml
                export CMD="kubectl apply -f ./${MANIFEST_TYPE}.yaml"
                ;;
        *)
                echo "Unknown MANIFEST_TYPE ${MANIFEST_TYPE}"
                ;;
esac

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "$CMD"

# Verify: list everything this deployment created (empty until pods schedule)
kubectl -n ${NAMESPACE} get deploy,lws,dgd,svc,pods -l app.kubernetes.io/part-of=${DEPLOYMENT_NAME} 2>/dev/null

