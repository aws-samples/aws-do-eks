#!/bin/bash

source .env

if [ "${MANIFEST_TYPE}" == "" ]; then
	export MANIFEST_TYPE=deployment
fi

export CMD=""

if [ "${MANIFEST_TYPE}" == "deployment" ]; then

	cat deployment.yaml-template | envsubst > deployment.yaml
	export CMD="kubectl delete -f ./deployment.yaml"

elif [ "${MANIFEST_TYPE}" == "lws" ]; then

	cat lws.yaml-template | envsubst > lws.yaml
	export CMD="kubectl delete -f ./lws.yaml"

else

	echo "Unknown MANIFEST_TYPE ${MANIFEST_TYPE}"

fi

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "$CMD"

export CMD="kubectl delete pods \$(kubectl get pods | grep ${DEPLOYMENT_NAME} | cut -d ' ' -f 1)"
if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "$CMD"
