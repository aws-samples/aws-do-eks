#!/bin/bash

CLUSTER=$1
NODEGROUP=$2
if [ "$NODEGROUP" == "" ]; then
	echo ""
	echo "Usage: $0 <cluster_name> <nodegroup_name>"
	echo ""
else
	CMD="aws eks delete-nodegroup --cluster-name $CLUSTER --nodegroup-name $NODEGROUP --output text"
	echo ""
	echo "$CMD"
	echo ""
	eval "$CMD"
fi

