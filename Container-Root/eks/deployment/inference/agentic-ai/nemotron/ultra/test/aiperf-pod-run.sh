#!/bin/bash

# Ref: https://github.com/iankoulski/do-aiperf

echo ""
echo "Starting do-aiperf pod ..."

# One line simple
#kubectl run -it --rm do-aiperf --image iankoulski/do-aiperf -- bash

# One line with node selector and volume mount
#kubectl run do-aiperf --image=iankoulski/do-aiperf --overrides='{"spec": {"nodeSelector": {"nvidia.com/gpu.present": "true"},"containers": [{"name": "do-aiperf","image": "iankoulski/do-aiperf","volumeMounts": [{"name": "fsx-vol", "mountPath": "/shared"}]}],"volumes": [{"name": "fsx-vol", "persistentVolumeClaim": {"claimName": "fsx-pvc"}}]}}' -- bash 

# Multi line with node selector and volume mount
kubectl run do-aiperf \
  --image=iankoulski/do-aiperf \
  --overrides='{
    "spec": {
      "nodeSelector": {"nvidia.com/gpu.present": "true"},
      "containers": [{
        "name": "do-aiperf",
        "image": "iankoulski/do-aiperf",
        "volumeMounts": [{"name": "fsx-vol", "mountPath": "/shared"}]
      }],
      "volumes": [{"name": "fsx-vol", "persistentVolumeClaim": {"claimName": "fsx-pvc"}}]
    }
  }' 




