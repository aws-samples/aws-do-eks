#!/bin/bash

source ./nodegroup.conf

if [ "$CLUSTER" == "" ]; then
	CLUSTER=$1
fi

if [ "$CLUSTER" == "" ]; then
	echo ""
	echo "Usage: $0 [CLUSTER]"
	echo "CLUSTER must be specified either in nodegroup.conf or as command line argument"
	echo ""
else
	CMD="aws eks list-nodegroups --cluster-name $CLUSTER --output text"
	echo ""
	echo "$CMD"
	echo ""
	eval "$CMD"
fi

