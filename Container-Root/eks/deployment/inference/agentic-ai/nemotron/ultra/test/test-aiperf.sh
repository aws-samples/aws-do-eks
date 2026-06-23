#!/bin/bash

# Ref: https://github.com/ai-dynamo/aiperf
# Ref: https://github.com/iankoulski/do-aiperf

source .env

# Start the do-aiperf pod
source ./aiperf-pod-run.sh

# Wait for pod to be running
echo "Waiting for the do-aiperf pod to be ready..."
kubectl wait --for=condition=Ready pod/do-aiperf --timeout=120s

# Execute the aiperf command interactively
echo "Executing aiperf command in do-aiperf pod ..."

export CMD="kubectl exec -it do-aiperf -- aiperf profile --model \"${MODEL_NAME}\" --tokenizer \"${MODEL_PATH}\" --url \"${SERVICE_URL}\" --transport http --endpoint-type chat --streaming --concurrency 10 --request-count 100 --synthetic-input-tokens-mean 1024 --synthetic-input-tokens-stddev 0 --output-tokens-mean 512 --extra-inputs \"ignore_eos:true\" --random-seed 42"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi

eval "${CMD}"

# Clean up
source ./aiperf-pod-stop.sh
