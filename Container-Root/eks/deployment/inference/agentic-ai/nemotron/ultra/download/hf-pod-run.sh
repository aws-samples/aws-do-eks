#!/bin/bash

echo ""
echo "Starting do-hf pod ..."

# Multi line with node selector and volume mount
kubectl run do-hf \
  --image=iankoulski/do-hf \
  --overrides='{
    "spec": {
      "nodeSelector": {"nvidia.com/gpu.present": "true"},
      "containers": [{
        "name": "do-hf",
        "image": "iankoulski/do-hf",
        "volumeMounts": [{"name": "fsx-vol", "mountPath": "/shared"}]
      }],
      "volumes": [{"name": "fsx-vol", "persistentVolumeClaim": {"claimName": "fsx-pvc"}}]
    }
  }'

