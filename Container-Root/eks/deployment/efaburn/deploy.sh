#!/bin/bash

. .env

cat efaburn-daemonset.yaml-template | envsubst > efaburn-daemonset.yaml

CMD="kubectl apply -f ./efaburn-daemonset.yaml"

if [ ! "$VERBOSE" == "false" ]; then
	echo "$CMD"
fi
eval "$CMD"

