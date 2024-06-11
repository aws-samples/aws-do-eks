#!/bin/bash

CMD="kubectl delete -f ./efaburn-daemonset.yaml"

if [ ! "$VERBOSE" == "false" ]; then
	echo "$CMD"
fi
eval "$CMD"

