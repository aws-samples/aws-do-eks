#!/bin/bash

help(){
	echo ""
	echo "This command runs a htop container on a specified node in your cluster"
	echo ""
	echo "Usage: $0 <node_name>"
	echo ""
}

if [ "$1" == "" ]; then
	help
else
	node_name=$1
	CMD="kubectl run -it --rm htop --image iankoulski/do-htop:latest --overrides='{\"apiVersion\": \"v1\", \"spec\": {\"nodeSelector\": { \"kubernetes.io/hostname\": \"$node_name\" }}}' --command -- htop"
	if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
	eval "$CMD"
fi

