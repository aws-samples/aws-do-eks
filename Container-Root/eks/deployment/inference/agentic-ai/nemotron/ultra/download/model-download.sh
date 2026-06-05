#!/bin/bash

source .env

# Start the do-aiperf pod
source ./hf-pod-run.sh

# Wait for pod to be running
echo "Waiting for the do-hf pod to be ready..."
kubectl wait --for=condition=Ready pod/do-hf --timeout=120s

# Execute the aiperf command interactively
echo "Executing hf command in do-hf pod ..."
kubectl exec -it do-hf -- bash -c "export HF_TOKEN=${HF_TOKEN}; hf download ${MODEL_NAME} --local-dir ${MODEL_PATH}"

# Clean up
source ./hf-pod-stop.sh

