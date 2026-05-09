#!/bin/bash

help(){
        echo ""
        echo "This command runs a netork interface monitoring container on a specified node in your cluster"
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
        short_node_name=$(echo $full_node_name | cut -d '.' -f 1)
        pod_name=iftop-${short_node_name:-4}	
	has_pod=$(kubectl get pods | grep ${pod_name} | wc -l)
	if [ "$has_pod" == "0" ]; then
        	CMD="kubectl run -it --rm --privileged=true $pod_name --image iankoulski/efatop:latest --overrides='{\"apiVersion\": \"v1\", \"spec\": { \"nodeSelector\": { \"kubernetes.io/hostname\": \"$full_node_name\" }, \"volumes\": [ {\"name\": \"sys-vol\", \"hostPath\": { \"path\": \"/sys\", \"type\": \"\" }}], \"containers\":  [ { \"name\": \"iftop\", \"image\": \"iankoulski/efatop:latest\", \"tty\": true, \"stdin\": true, \"command\": [\"bash\",\"-c\",\"bmon\"], \"volumeMounts\": [{ \"name\": \"sys-vol\", \"mountPath\": \"/sys\"}] } ] } }'"
	else
		CMD="kubectl exec -it $pod_name -- bmon"
	fi
        if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
        eval "$CMD"
fi

