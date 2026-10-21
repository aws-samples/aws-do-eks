#!/bin/bash

echo ""
echo "Starting do-hf pod ..."

# The download pod needs only the fsx-pvc volume, not a GPU node. The former hard pin
# nodeSelector {"nvidia.com/gpu.present": "true"} is a GPU-operator / NFD label that EKS Auto Mode
# GPU nodes do not carry, and the pod has no GPU toleration, so on an Auto Mode cluster it stayed
# Pending (observed 2026-10-19 on a p5e.48xlarge Auto Mode cluster). Default: no node pin, so the
# pod lands on any schedulable node of a traditional or an Auto Mode cluster. To restore the
# GPU-node pin on a cluster that carries the label:
#   HF_POD_NODE_SELECTOR='{"nvidia.com/gpu.present": "true"}' ./model-download.sh
_HF_POD_NODE_SELECTOR_DEFAULT='{}'
export HF_POD_NODE_SELECTOR="${HF_POD_NODE_SELECTOR:-${_HF_POD_NODE_SELECTOR_DEFAULT}}"

export CMD="kubectl run do-hf \
  --image=iankoulski/do-hf \
  --overrides='{
    \"spec\": {
      \"nodeSelector\": ${HF_POD_NODE_SELECTOR},
      \"containers\": [{
        \"name\": \"do-hf\",
        \"image\": \"iankoulski/do-hf\",
        \"volumeMounts\": [{\"name\": \"fsx-vol\", \"mountPath\": \"/shared\"}]
      }],
      \"volumes\": [{\"name\": \"fsx-vol\", \"persistentVolumeClaim\": {\"claimName\": \"fsx-pvc\"}}]
    }
  }'"
if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "${CMD}"
