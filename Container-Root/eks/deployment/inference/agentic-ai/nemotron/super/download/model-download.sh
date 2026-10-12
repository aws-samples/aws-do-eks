#!/bin/bash

source .env

# Start the do-hf pod
source ./hf-pod-run.sh

# Wait for pod to be running
echo "Waiting for the do-hf pod to be ready..."
kubectl wait --for=condition=Ready pod/do-hf --timeout=120s

# Execute the hf command in do-hf pod
export CMD="kubectl exec -it do-hf -- bash -c \"export HF_TOKEN=${HF_TOKEN}; hf download ${MODEL_NAME} --local-dir ${MODEL_PATH}\""
if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "${CMD}"

# Clean up
source ./hf-pod-stop.sh
