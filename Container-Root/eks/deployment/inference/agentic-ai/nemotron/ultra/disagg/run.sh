#!/bin/bash

source .env

if [ "${MANIFEST_TYPE}" == "" ]; then
	export MANIFEST_TYPE=deployment
fi

if [ "${MANIFEST_TYPE}" == "deployment" ]; then

	cat deployment.yaml-template | envsubst > deployment.yaml
	kubectl apply -f ./deployment.yaml

elif [ "${MANIFEST_TYPE}" == "lws" ]; then

	cat lws.yaml-template | envsubst > lws.yaml
	kubectl apply -f ./lws.yaml

else
	echo "Unknown MANIFEST_TYPE ${MANIFEST_TYPE}"
fi

