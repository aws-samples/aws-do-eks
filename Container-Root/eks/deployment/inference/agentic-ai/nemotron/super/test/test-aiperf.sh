#!/bin/bash

# Ref: https://github.com/ai-dynamo/aiperf
# Ref: https://github.com/iankoulski/do-aiperf
#
# Default = the LLM text workload, flag-for-flag identical to ../../ultra/test/test-aiperf.sh
# (chat endpoint, --concurrency 10, --request-count 100, ISL 1024 stddev 0 / OSL 512,
# ignore_eos, --random-seed 42, same warmup phase), so a Super row compares directly with
# the c=10 rows in ../../ultra/test/RESULTS.md. The vision workload is optional:
# AIPERF_WORKLOAD=vl ./test-aiperf.sh adds synthetic images to every request
# (--image-width-mean/--image-height-mean — aiperf generates random-noise images at the
# requested dimensions; flags per aiperf v0.9.0 docs/tutorials/vision.md). The default
# 512x512 matches the checkpoint's force_image_size; AIPERF_IMAGE_WIDTH/HEIGHT in .env
# change it. A vl run is written under a vl- run id so it is never read as an LLM row.

source .env

# Workload selection. Validated here, BEFORE the do-aiperf pod is started, so a typo cannot
# leave a pod behind. _IMAGE_ARGS carries its own leading space: with llm it is empty and
# the rendered command is byte-identical to ultra's.
export AIPERF_WORKLOAD="${AIPERF_WORKLOAD:-llm}"
case "${AIPERF_WORKLOAD}" in
  llm) _IMAGE_ARGS="" ;;
  vl)  _IMAGE_ARGS=" --image-width-mean ${AIPERF_IMAGE_WIDTH} --image-height-mean ${AIPERF_IMAGE_HEIGHT}" ;;
  *)
    echo "ERROR: AIPERF_WORKLOAD='${AIPERF_WORKLOAD}' is not one of: llm (default, ultra-comparable text), vl (synthetic images)" >&2
    exit 1
    ;;
esac
echo "Workload: ${AIPERF_WORKLOAD}"

# Every kubectl call that touches the do-aiperf pod passes the namespace explicitly, so a
# kubeconfig context pinned to another namespace cannot strand the pod (or these lookups)
# somewhere fsx-pvc and the model do not exist. Empty NAMESPACE keeps the old context-default
# behaviour.
_NS_ARG=""
if [ "${NAMESPACE}" != "" ]; then _NS_ARG="-n ${NAMESPACE}"; fi

# Start the do-aiperf pod
source ./aiperf-pod-run.sh

# Wait for pod to be running
AIPERF_POD_NAME="${AIPERF_POD_NAME:-do-aiperf}"
echo "Waiting for the ${AIPERF_POD_NAME} pod to be ready..."
kubectl ${_NS_ARG} wait --for=condition=Ready pod/${AIPERF_POD_NAME} --timeout=120s

# Pin the aiperf version (AIPERF_VERSION in .env, default 0.13.0). The iankoulski/do-aiperf image
# ships 0.9.0, whose extract_chat_response_data raises on a streaming chunk without an "object"
# key (ai-dynamo/aiperf#1010, fixed by PR #1026, first in v0.11.0). Upgrade in place only when the
# installed version differs, so a pod that already carries the pinned version is untouched.
AIPERF_VERSION="${AIPERF_VERSION:-0.13.0}"
_AIPERF_HAVE="$(kubectl ${_NS_ARG} exec ${AIPERF_POD_NAME} -- aiperf --version 2>/dev/null | tr -d '\r\n')"
if [ "${_AIPERF_HAVE}" != "${AIPERF_VERSION}" ]; then
  echo "aiperf in pod is '${_AIPERF_HAVE}', installing aiperf==${AIPERF_VERSION} ..."
  kubectl ${_NS_ARG} exec ${AIPERF_POD_NAME} -- pip install -q "aiperf==${AIPERF_VERSION}" || { echo "ERROR: pip install aiperf==${AIPERF_VERSION} failed" >&2; source ./aiperf-pod-stop.sh; exit 1; }
fi
echo "aiperf $(kubectl ${_NS_ARG} exec ${AIPERF_POD_NAME} -- aiperf --version 2>/dev/null | tr -d '\r\n')"

# AIPerf runs a separate Warmup phase and EXCLUDES those records from the report, which is
# what keeps a cold engine out of the published numbers. On this model family the first
# requests pay a one-time Mamba decode Triton JIT (see the warmup block in the
# ../agg and ../disagg templates), and without this the tax lands inside the measured
# sample. 30 is the count ../../ultra validated for this engine family; no Super cell has
# been measured yet, so treat it as a starting point, not a tuned value.
# AIPERF_WARMUP_REQUESTS=0 disables, any integer overrides.
export AIPERF_WARMUP_REQUESTS="${AIPERF_WARMUP_REQUESTS:-auto}"
case "${AIPERF_WARMUP_REQUESTS}" in
  auto) _WARMUP_COUNT=30 ;;
  *)    _WARMUP_COUNT="${AIPERF_WARMUP_REQUESTS}" ;;
esac
_WARMUP_ARG=""
if [ "${_WARMUP_COUNT}" -gt 0 ] 2>/dev/null; then
  _WARMUP_ARG="--warmup-request-count ${_WARMUP_COUNT}"
  echo "Adding ${_WARMUP_ARG} (a separate phase, excluded from the report)"
fi

# Artifact directory. ${MODEL_PATH}/aiperf/${DEPLOYMENT_TYPE} alone is not unique per run:
# every topology in a folder shares one DEPLOYMENT_TYPE, so two runs would overwrite each
# other's profile_export.jsonl. Scoping by MANIFEST_TYPE and run id keeps every run
# readable and comparable. AIPERF_RUN_ID can be set to any label ("cold", "warm").
# llm runs use ultra's exact layout so the two folder trees read the same; a vl run id is
# prefixed vl- so a vision report can never be mistaken for an LLM row.
export AIPERF_RUN_ID="${AIPERF_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
if [ "${AIPERF_WORKLOAD}" == "vl" ]; then
  case "${AIPERF_RUN_ID}" in
    vl-*) ;;
    *)    AIPERF_RUN_ID="vl-${AIPERF_RUN_ID}" ;;
  esac
fi
export ARTIFACT_DIR="${MODEL_PATH}/aiperf/${DEPLOYMENT_TYPE}/${MANIFEST_TYPE}/${AIPERF_RUN_ID}"
echo "Artifacts: ${ARTIFACT_DIR}"

# Execute the aiperf command interactively
echo "Executing aiperf command in ${AIPERF_POD_NAME} pod ..."

export CMD="kubectl ${_NS_ARG} exec -it ${AIPERF_POD_NAME} -- aiperf profile --model \"${MODEL_NAME}\" --tokenizer \"${MODEL_PATH}\" --artifact-dir \"${ARTIFACT_DIR}\" --url \"${SERVICE_URL}\" --transport http --endpoint-type chat --streaming --concurrency 10 --request-count 100 ${_WARMUP_ARG}${_IMAGE_ARGS} --synthetic-input-tokens-mean 1024 --synthetic-input-tokens-stddev 0 --output-tokens-mean 512 --extra-inputs \"ignore_eos:true\" --random-seed 42"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi

eval "${CMD}"

# Record what actually served this run, next to its report. ${MANIFEST_TYPE} names the
# artifact folder but nothing ever reads it back from the cluster, so a stale value in .env
# silently mislabels a report (observed repeatedly on the ultra campaigns). The fields and
# their evidentiary value are documented in ../../ultra/test/test-aiperf.sh; the mechanism
# is identical here.
echo ""
echo "Recording run-meta.json ..."
_SVC="$(echo "${SERVICE_URL}" | sed -E 's#^[a-z]+://##; s#[:/].*$##; s#\..*$##')"
_PART_OF="${_SVC%-frontend}"
_FE_POD="$(kubectl ${_NS_ARG} get endpointslices -l "kubernetes.io/service-name=${_SVC}" -o jsonpath='{.items[0].endpoints[0].targetRef.name}' 2>/dev/null)"
_OBS_NS="$(kubectl ${_NS_ARG} exec "${_FE_POD}" -- printenv DYN_NAMESPACE 2>/dev/null | tr -d '\r\n')"
_FE_OWNER="$(kubectl ${_NS_ARG} get pod "${_FE_POD}" -o jsonpath='{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}' 2>/dev/null)"
_WORKLOADS="$(kubectl ${_NS_ARG} get deployments,statefulsets -l "app.kubernetes.io/part-of=${_PART_OF}" -o jsonpath='{range .items[*]}{.kind}/{.metadata.name} {end}' 2>/dev/null)"
_DGDS="$(kubectl ${_NS_ARG} get dynamographdeployments -o jsonpath='{range .items[*]}{.metadata.name} {end}' 2>/dev/null)"

# Expected namespace for the topology this report claims to be, read from the template itself.
_TPL="../${DEPLOYMENT_TYPE}/${MANIFEST_TYPE}.yaml-template"
_EXP_NS="$(grep -m1 -o 'name: DYN_NAMESPACE, value: [A-Za-z0-9_-]*' "${_TPL}" 2>/dev/null | awk '{print $NF}')"
if [ ! -f "${_TPL}" ]; then
  _CHECK="unverified: ${_TPL} not found from $(pwd), so the asserted topology could not be read"
elif [ "${_EXP_NS}" == "" ]; then
  # Single quotes around the values, not double: _CHECK lands inside a JSON string in the
  # heredoc below, and a literal double quote there makes the whole run-meta.json unparsable.
  _CHECK="not discriminating: ${MANIFEST_TYPE}.yaml-template sets no DYN_NAMESPACE, dynamo defaults it to 'dynamo', observed '${_OBS_NS}' -- use the workloads field to identify this run"
elif [ "${_EXP_NS}" == "${_OBS_NS}" ]; then
  _CHECK="consistent: ${MANIFEST_TYPE} sets DYN_NAMESPACE=${_EXP_NS} and the serving frontend reports ${_OBS_NS}"
else
  _CHECK="MISMATCH: ${MANIFEST_TYPE} sets DYN_NAMESPACE=${_EXP_NS} but the serving frontend reports '${_OBS_NS}' -- this report is in the wrong folder"
fi

# Emit the warm-up count as a JSON number only when it is one (a typo must not produce a
# run-meta.json that will not parse).
case "${_WARMUP_COUNT}" in
  ''|*[!0-9]*) _WARMUP_JSON="\"${_WARMUP_COUNT}\"" ;;
  *)           _WARMUP_JSON="${_WARMUP_COUNT}" ;;
esac
# The image dimensions are recorded only when they were sent (vl); an llm run-meta.json has
# the same keys as ultra's plus "workload".
case "${AIPERF_WORKLOAD}" in
  vl) _IMAGE_JSON=", \"image_width_mean\": ${AIPERF_IMAGE_WIDTH}, \"image_height_mean\": ${AIPERF_IMAGE_HEIGHT}" ;;
  *)  _IMAGE_JSON="" ;;
esac

kubectl ${_NS_ARG} exec -i ${AIPERF_POD_NAME} -- sh -c "mkdir -p '${ARTIFACT_DIR}' && cat > '${ARTIFACT_DIR}/run-meta.json'" <<EOF
{
  "run_id": "${AIPERF_RUN_ID}",
  "aiperf_version": "${AIPERF_VERSION}",
  "recorded_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "asserted": {
    "deployment_type": "${DEPLOYMENT_TYPE}",
    "manifest_type": "${MANIFEST_TYPE}",
    "model_name": "${MODEL_NAME}",
    "model_path": "${MODEL_PATH}",
    "service_url": "${SERVICE_URL}",
    "warmup_requests": ${_WARMUP_JSON},
    "workload": "${AIPERF_WORKLOAD}"${_IMAGE_JSON}
  },
  "observed": {
    "frontend_pod": "${_FE_POD}",
    "frontend_owner": "${_FE_OWNER}",
    "dyn_namespace": "${_OBS_NS}",
    "workloads": "${_WORKLOADS}",
    "dynamographdeployments": "${_DGDS}"
  },
  "label_check": "${_CHECK}"
}
EOF
if [ $? -eq 0 ]; then
  echo "${ARTIFACT_DIR}/run-meta.json"
else
  echo "WARNING: could not write run-meta.json -- the benchmark report itself is unaffected"
fi
echo "${_CHECK}"

# Clean up
source ./aiperf-pod-stop.sh
