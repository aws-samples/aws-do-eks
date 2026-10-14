#!/bin/bash

echo ""
echo "Starting do-ngc pod ..."

export CMD="kubectl run do-ngc \
  --image=iankoulski/do-ngc \
  --overrides='{
    \"spec\": {
      \"containers\": [{
        \"name\": \"do-ngc\",
        \"image\": \"iankoulski/do-ngc\",
	\"command\": [\"bash\", \"-c\", \"chmod +x /*.sh && /startup.sh\"],
        \"volumeMounts\": [{\"name\": \"fsx-vol\", \"mountPath\": \"/shared\"}]
      }],
      \"volumes\": [{\"name\": \"fsx-vol\", \"persistentVolumeClaim\": {\"claimName\": \"fsx-pvc\"}}]
    }
  }'"
if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "${CMD}"
