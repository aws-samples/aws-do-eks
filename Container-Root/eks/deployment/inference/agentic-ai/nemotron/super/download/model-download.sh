#!/bin/bash

source .env

# No default NGC_MODEL ships in .env (the EA org/team path is entitlement-specific).
# Fail here, loudly, rather than inside the pod.
if [ "${NGC_MODEL}" == "" ]; then
  echo "ERROR: NGC_MODEL is not set. Run ./config.sh and set it to the EA model string"
  echo "       from your NGC entitlement, e.g. NGC_MODEL=\"<org>/<team>/<model>:<version>\""
  exit 1
fi

# Start the do-ngc pod (reads the API key from the ${NGC_SECRET_NAME} Secret)
source ./ngc-pod-run.sh

# Wait for pod to be running
echo "Waiting for the do-ngc pod to be ready..."
kubectl wait --for=condition=Ready pod/do-ngc --timeout=120s

# Execute the ngc download in the do-ngc pod. The CLI reads NGC_CLI_API_KEY from the
# pod environment (injected from the Secret) — no key material appears on this command line.
# `ngc registry model download-version` creates ${DOWNLOAD_ROOT}/<model>_v<version>/.
export CMD="kubectl exec -it do-ngc -- bash -c \"mkdir -p ${DOWNLOAD_ROOT} && ngc registry model download-version \\\"${NGC_MODEL}\\\" --dest \\\"${DOWNLOAD_ROOT}\\\"\""
if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "${CMD}"

# Show what landed (the directory name is what MODEL_PATH in ../agg/.env and
# ../disagg/.env must point at)
kubectl exec do-ngc -- bash -c "ls -la ${DOWNLOAD_ROOT}"

# Clean up
source ./ngc-pod-stop.sh
