#!/bin/bash

help(){
	echo ""
	echo "$0 - lists cluster nodes with custom columns"
	echo "" 
	echo "Usage: $0 [node_name]"
	echo "       node_name - optional, partial or full name of the node to display"
	echo "                   if a partial name is specified that matches more than one node"
	echo "                   then all matching nodes will be displayed"
	echo ""
}

if [ "$1" == "--help" ]; then
	help
else

	node=$1

	shift

	if [ "$node" == "" ]; then
		CMD="kubectl get nodes -o 'custom-columns=NAME:.metadata.name,STATUS:status.conditions[-1].type,HEALTH:.metadata.labels.sagemaker\.amazonaws\.com/node-health-status,CHECKS:.metadata.labels.sagemaker\.amazonaws\.com\/deep-health-check-status,ROLES:.metadata.labels.node-role\\.kubernetes\\.io/control-plane,CREATED:.metadata.creationTimestamp,ZONE:.metadata.labels.topology\.kubernetes\.io/zone,INSTANCE-TYPE:.metadata.labels.node\.kubernetes\.io/instance-type,MEMORY:.status.allocatable.memory,CPU:.status.allocatable.cpu,GPU:.status.allocatable.nvidia\.com/gpu,EFA:.status.allocatable.vpc\.amazonaws\.com/efa,PODS:.status.allocatable.pods' $@"
	else
		CMD="kubectl get nodes -o 'custom-columns=NAME:.metadata.name,STATUS:status.conditions[-1].type,HEALTH:.metadata.labels.sagemaker\.amazonaws\.com/node-health-status,CHECKS:.metadata.labels.sagemaker\.amazonaws\.com\/deep-health-check-status,ROLES:.metadata.labels.node-role\\.kubernetes\\.io/control-plane,CREATED:.metadata.creationTimestamp,ZONE:.metadata.labels.topology\.kubernetes\.io/zone,INSTANCE-TYPE:.metadata.labels.node\.kubernetes\.io/instance-type,MEMORY:.status.allocatable.memory,CPU:.status.allocatable.cpu,GPU:.status.allocatable.nvidia\.com/gpu,EFA:.status.allocatable.vpc\.amazonaws\.com/efa,PODS:.status.allocatable.pods' $@ | grep -E \"NAME|$node\""
	fi

	if [ "${VERBOSE}" == "true" ]; then
		echo ""
		echo "${CMD}"
		echo ""
	fi

	if [ ! "${DRY_RUN}" == "true" ]; then
		eval "${CMD}"
	fi

fi


