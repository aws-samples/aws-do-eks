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
	short_node_name=$(echo $full_node_name | cut -d '.' -f 1)
        pod_name=neurontop-${short_node_name:-4}
        CMD="kubectl run -it --rm --privileged --pod-running-timeout=6m30s $pod_name --image 763104351884.dkr.ecr.us-east-2.amazonaws.com/pytorch-training-neuronx:2.1.2-neuronx-py310-sdk2.19.1-ubuntu20.04 --overrides='{\"apiVersion\": \"v1\", \"spec\": {\"nodeSelector\": { \"kubernetes.io/hostname\": \"$full_node_name\" }}}' --command -- neuron-top"
        if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
        eval "$CMD"
fi

