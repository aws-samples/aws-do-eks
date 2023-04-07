#!/bin/bash

if [ "$1" == "" ]; then
	echo ""
	echo "Usage: $0 <deployment> [replicas]"
	echo ""
else
	deployment=$1
	replicas=$2
	if [ "$replicas" == "" ]; then
		replicas=1
	fi
	echo ""
	echo "Scaling deployment $deployment to $replicas replicas ..."
	kubectl scale deployment $deployment --replicas=$replicas
fi
