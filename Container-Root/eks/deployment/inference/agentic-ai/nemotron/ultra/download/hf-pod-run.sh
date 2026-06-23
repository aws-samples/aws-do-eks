#!/bin/bash

echo ""
echo "Starting do-hf pod ..."

export CMD="kubectl run do-hf \
  --image=iankoulski/do-hf \
  --overrides='{
    \"spec\": {
      \"nodeSelector\": {\"nvidia.com/gpu.present\": \"true\"},
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
