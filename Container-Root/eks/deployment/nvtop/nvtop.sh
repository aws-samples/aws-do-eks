#!/bin/bash

help(){
	echo ""
	echo "This command runs an nvtop container on a specified node in your cluster"
	echo ""
	echo "Usage: $0 <node_name>"
	echo ""
}

if [ "$1" == "" ]; then
	help
else
	node_name=$1
	CMD="kubectl run -it --rm nvtop --image iankoulski/do-nvtop:latest --overrides='{\"apiVersion\": \"v1\", \"spec\": {\"nodeSelector\": { \"kubernetes.io/hostname\": \"$node_name\" }}}' --command -- nvtop"
	if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
	eval "$CMD"
fi

