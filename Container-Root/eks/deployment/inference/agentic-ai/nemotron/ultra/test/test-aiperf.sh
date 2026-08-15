#!/bin/bash

# Ref: https://github.com/ai-dynamo/aiperf
# Ref: https://github.com/iankoulski/do-aiperf

source .env

# Start the do-aiperf pod
source ./aiperf-pod-run.sh

# Wait for pod to be running
echo "Waiting for the do-aiperf pod to be ready..."
kubectl wait --for=condition=Ready pod/do-aiperf --timeout=120s

# AIPerf runs a separate Warmup phase and EXCLUDES those records from the report, which is
# what keeps a cold engine out of the published numbers. On NVFP4 the first requests pay a
# one-time Mamba decode Triton JIT (see the warmup block in ../disagg/*.yaml-template), and
# without this the tax lands inside the measured sample: a live 100-request NVFP4 disagg run
# (2026-08-15, p6-b200) reported TTFT max 340,349ms / p90 128,579ms against a p50 of 759ms,
# and ITL p50 146.77ms against ~124-129ms measured warm. 30 is derived, not picked: the JIT
# window on that run admitted ~31 requests = 3 full waves at --concurrency 10.
# The manifest-side warmer already primes the engine at pod start, so this is normally a
# no-op; it is what makes the benchmark reproducible when the pods ARE cold.
# auto (default) follows the model's precision suffix. AIPERF_WARMUP_REQUESTS=0 disables,
# any integer overrides. Same idiom as WARMUP_ENABLED in the manifests.
export AIPERF_WARMUP_REQUESTS="${AIPERF_WARMUP_REQUESTS:-auto}"
case "${AIPERF_WARMUP_REQUESTS}" in
  auto) case "${MODEL_NAME}" in *NVFP4*|*nvfp4*) _WARMUP_COUNT=30 ;; *) _WARMUP_COUNT=0 ;; esac ;;
  *)    _WARMUP_COUNT="${AIPERF_WARMUP_REQUESTS}" ;;
esac
_WARMUP_ARG=""
if [ "${_WARMUP_COUNT}" -gt 0 ] 2>/dev/null; then
  _WARMUP_ARG="--warmup-request-count ${_WARMUP_COUNT}"
  echo "NVFP4 model detected: adding ${_WARMUP_ARG} (excluded from the report)"
fi

# Execute the aiperf command interactively
echo "Executing aiperf command in do-aiperf pod ..."

export CMD="kubectl exec -it do-aiperf -- aiperf profile --model \"${MODEL_NAME}\" --tokenizer \"${MODEL_PATH}\" --artifact-dir \"${MODEL_PATH}/aiperf/${DEPLOYMENT_TYPE}\" --url \"${SERVICE_URL}\" --transport http --endpoint-type chat --streaming --concurrency 10 --request-count 100 ${_WARMUP_ARG} --synthetic-input-tokens-mean 1024 --synthetic-input-tokens-stddev 0 --output-tokens-mean 512 --extra-inputs \"ignore_eos:true\" --random-seed 42"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi

eval "${CMD}"

# Clean up
source ./aiperf-pod-stop.sh
