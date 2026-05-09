#!/bin/bash

help(){
	echo ""
	echo "This command runs a neurontop container on a specified node in your cluster"
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
	has_neuron=$(kubectl describe node ${full_node_name} | grep Capacity -A 8 | grep neuron | wc -l)
	if [ "${has_neuron}" == "0" ]; then
		echo "ERROR: node ${full_node_name} does not have any neuron devices" >&2
		exit 1
	fi
	host_name=$(echo $full_node_name | cut -d '.' -f 1)
	pod_name=neurontop-${host_name}
	has_pod=$(kubectl get pods | grep ${pod_name} | wc -l)
	if [ "$has_pod" == "0" ]; then
		CMD="kubectl run -it --rm --privileged --pod-running-timeout=6m30s $pod_name --image 763104351884.dkr.ecr.us-east-2.amazonaws.com/pytorch-training-neuronx:2.1.2-neuronx-py310-sdk2.19.1-ubuntu20.04 --overrides='{\"apiVersion\": \"v1\", \"spec\": {\"nodeSelector\": { \"kubernetes.io/hostname\": \"$full_node_name\" }}}' --command -- neuron-top"
	else
		CMD="kubectl exec -it $pod_name -- neuron-top"
	fi
	if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
	eval "$CMD"
fi

