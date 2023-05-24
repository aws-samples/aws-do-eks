#!/bin/bash

#Reference: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#run

usage() {
	echo ""
	echo "Usage: $0 <image> [command]"
	echo ""
}

IMAGE="$1"
if [ "$1" == "" ]; then
	IMAGE=ubuntu:20.04
fi

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
	usage
else
	if [ "$2" == "" ]; then
		CMD="sh -c 'while true; do date; sleep 10; done'"
	else
		shift
		CMD="$@"
		OPTS="-it --rm"
	fi

	KCMD="kubectl run ${OPTS} pod --image=$IMAGE --command -- $CMD"

	echo "$KCMD"

	eval "$KCMD"
fi
