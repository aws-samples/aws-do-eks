#!/bin/bash

CLUSTER=$1
if [ "$CLUSTER" == "" ]; then
	echo ""
	echo "Usage: $0 <cluster_name>"
	echo ""
else
	CMD="aws eks list-nodegroups --cluster-name $CLUSTER --output text"
	echo ""
	echo "$CMD"
	echo ""
	eval "$CMD"
fi

