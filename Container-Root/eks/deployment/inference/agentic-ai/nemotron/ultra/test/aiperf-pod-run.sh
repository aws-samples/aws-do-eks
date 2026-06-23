#!/bin/bash

# Ref: https://github.com/iankoulski/do-aiperf

echo ""
echo "Starting do-aiperf pod ..."

export CMD="kubectl run do-aiperf --image=iankoulski/do-aiperf --overrides='{\"spec\": {\"nodeSelector\": {\"nvidia.com/gpu.present\": \"true\"}, \"containers\": [{\"name\": \"do-aiperf\", \"image\": \"iankoulski/do-aiperf\", \"volumeMounts\": [{\"name\": \"fsx-vol\", \"mountPath\": \"/shared\"}]}], \"volumes\": [{\"name\": \"fsx-vol\", \"persistentVolumeClaim\": {\"claimName\": \"fsx-pvc\"}}]}}'"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi

eval "${CMD}"
