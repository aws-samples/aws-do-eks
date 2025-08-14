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
        short_node_name=$(echo $full_node_name | cut -d '.' -f 1)
        pod_name=efatop-${short_node_name:-4}	
        CMD="kubectl run -it --rm --privileged=true $pod_name --image iankoulski/efatop:latest --overrides='{\"apiVersion\": \"v1\", \"spec\": { \"nodeSelector\": { \"kubernetes.io/hostname\": \"$full_node_name\" }, \"volumes\": [ {\"name\": \"sys-vol\", \"hostPath\": { \"path\": \"/sys\", \"type\": \"\" }}], \"containers\":  [ { \"name\": \"efatop\", \"image\": \"iankoulski/efatop:latest\", \"tty\": true, \"stdin\": true, \"command\": [\"bash\",\"-c\",\"efatop\"], \"volumeMounts\": [{ \"name\": \"sys-vol\", \"mountPath\": \"/sys\"}] } ] } }'"
        if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
        eval "$CMD"
fi

