#!/bin/bash

help(){
        echo ""
        echo "This command runs an efatop container on a specified node in your cluster"
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
	has_efa=$(kubectl describe ndoes ${full_node_name} | grep Capacity -A 8 | grep efa | wc -l)
	if [ "${has_efa}" == "0" ]; then
		echo "ERROR: node ${full_node_name} does not hae any EFA devices" >&2
		exit 1
	fi
        short_node_name=$(echo $full_node_name | cut -d '.' -f 1)
        pod_name=efatop-${short_node_name:-4}	
	has_pod=$(kubectl get pods | grep ${pod_name} | wc -l)
	if [ "$has_pod" == "0" ]; then
        	CMD="kubectl run -it --rm --privileged=true $pod_name --image iankoulski/efatop:latest --overrides='{\"apiVersion\": \"v1\", \"spec\": { \"nodeSelector\": { \"kubernetes.io/hostname\": \"$full_node_name\" }, \"volumes\": [ {\"name\": \"sys-vol\", \"hostPath\": { \"path\": \"/sys\", \"type\": \"\" }}], \"containers\":  [ { \"name\": \"efatop\", \"image\": \"iankoulski/efatop:latest\", \"tty\": true, \"stdin\": true, \"command\": [\"bash\",\"-c\",\"efatop\"], \"volumeMounts\": [{ \"name\": \"sys-vol\", \"mountPath\": \"/sys\"}] } ] } }'"
	else
		CMD="kubectl exec -it ${pod_name} -- efatop"
	fi
        if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
        eval "$CMD"
fi

