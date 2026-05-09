#!/bin/bash

help(){
	echo ""
	echo "This command runs an nvtop container on a specified node in your cluster"
	echo ""
	echo "Usage: $0 <node_name>"
	echo ""
	echo "       node_name - full or partial name of the node to use"
	echo "                   If partial name matches multiple nodes,"
	echo "                   then the first matching node will be used"
	echo ""
}

if [ "$1" == "" ]; then
	help
else
	node_name=$1
	full_node_name=$(kubectl get nodes | grep $node_name | head -n 1 | cut -d ' ' -f 1)
	if [ -z "$full_node_name" ]; then
		echo "ERROR: no node matches '${node_name}'" >&2
		exit 1
	fi
        has_gpu=$(kubectl describe node ${full_node_name} | grep Capacity -A 8 | grep gpu | wc -l)
	if [ "${has_gpu}" == "0" ]; then
		echo "ERROR: node ${full_node_name} does not have any GPUs" >&2
		exit 1
	fi
	host_name=$(echo $full_node_name | cut -d '.' -f 1)
	pod_name=nvtop-${host_name}
	has_pod=$(kubectl get pods | grep ${pod_name} | wc -l)
	if [ "$has_pod" == "0" ]; then
		CMD="kubectl run -it --rm $pod_name --image iankoulski/do-nvtop:latest --overrides='{\"apiVersion\": \"v1\", \"spec\": {\"nodeSelector\": { \"kubernetes.io/hostname\": \"$full_node_name\" }}}' --command -- nvtop"
        else
		CMD="kubectl exec -it $pod_name -- nvtop"
	fi
	if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
	eval "$CMD"
fi

