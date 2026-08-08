#!/bin/bash

source .env

if [ "${MANIFEST_TYPE}" == "" ]; then
	export MANIFEST_TYPE=deployment
fi

export CMD=""

if [ "${MANIFEST_TYPE}" == "deployment" ]; then

	cat deployment.yaml-template | envsubst > deployment.yaml
	export CMD="kubectl apply -f ./deployment.yaml"

elif [ "${MANIFEST_TYPE}" == "lws" ]; then

	cat lws.yaml-template | envsubst > lws.yaml
	export CMD="kubectl apply -f ./lws.yaml"

elif [ "${MANIFEST_TYPE}" == "ep16" ]; then

	# Wide-EP aggregated: DP=2 / TP=8 / EP=16 over EFA (2 nodes, vLLM-native DP).
	cat lws-ep16.yaml-template | envsubst > lws-ep16.yaml
	export CMD="kubectl apply -f ./lws-ep16.yaml"

else

	echo "Unknown MANIFEST_TYPE ${MANIFEST_TYPE}"

fi


if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "$CMD"

