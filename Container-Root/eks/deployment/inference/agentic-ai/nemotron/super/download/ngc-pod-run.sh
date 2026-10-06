#!/bin/bash

# Ref: https://hub.docker.com/r/iankoulski/do-ngc

if [ -f ./.env ]; then source ./.env; fi

echo ""
echo "Starting do-ngc pod ..."

# The NGC API key is injected from the Kubernetes Secret ${NGC_SECRET_NAME}
# (create it once: kubectl create secret generic ngc-api-key --from-literal=NGC_API_KEY=<key>).
# The key never appears in this repo, in the rendered command, or in the pod spec.
export CMD="kubectl run do-ngc \
  --image=iankoulski/do-ngc \
  --overrides='{
    \"spec\": {
      \"nodeSelector\": {\"nvidia.com/gpu.present\": \"true\"},
      \"containers\": [{
        \"name\": \"do-ngc\",
        \"image\": \"iankoulski/do-ngc\",
        \"env\": [{\"name\": \"NGC_CLI_API_KEY\", \"valueFrom\": {\"secretKeyRef\": {\"name\": \"${NGC_SECRET_NAME}\", \"key\": \"NGC_API_KEY\"}}}],
        \"volumeMounts\": [{\"name\": \"fsx-vol\", \"mountPath\": \"/shared\"}]
      }],
      \"volumes\": [{\"name\": \"fsx-vol\", \"persistentVolumeClaim\": {\"claimName\": \"fsx-pvc\"}}]
    }
  }'"
if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "${CMD}"
