#!/bin/bash

# Ref: https://github.com/ai-dynamo/aiperf
# Ref: https://github.com/iankoulski/do-aiperf

source .env

# Every kubectl call that touches the do-aiperf pod passes the namespace explicitly, so a
# kubeconfig context pinned to another namespace cannot strand the pod (or these lookups)
# somewhere fsx-pvc and the model do not exist. Empty NAMESPACE keeps the old context-default
# behaviour.
_NS_ARG=""
if [ "${NAMESPACE}" != "" ]; then _NS_ARG="-n ${NAMESPACE}"; fi

# Start the do-aiperf pod
source ./aiperf-pod-run.sh

# Wait for pod to be running
echo "Waiting for the do-aiperf pod to be ready..."
kubectl ${_NS_ARG} wait --for=condition=Ready pod/do-aiperf --timeout=120s

# AIPerf runs a separate Warmup phase and EXCLUDES those records from the report, which is
# what keeps a cold engine out of the published numbers. On NVFP4 the first requests pay a
# one-time Mamba decode Triton JIT (see the warmup block in ../disagg/*.yaml-template), and
# without this the tax lands inside the measured sample: a live 100-request NVFP4 disagg run
# (2026-08-15, p6-b200) reported TTFT max 340,349ms / p90 128,579ms against a p50 of 759ms,
# and ITL p50 146.77ms against ~124-129ms measured warm. 30 is derived, not picked: the JIT
# window on that run admitted ~31 requests = 3 full waves at --concurrency 10.
# The manifest-side warmer already primes the engine at pod start, so this is normally a
# no-op; it is what makes the benchmark reproducible when the pods ARE cold.
#
# This used to be precision-gated -- auto meant 30 for NVFP4 and 0 for everything else,
# on the reasoning that only the NVFP4 checkpoint pulls in the extra JIT. A BF16 run
# refutes that gate: BF16 disagg/lws-ep on p6-b200 (2026-08-17T06:01:40Z, 100 requests,
# ISL 1024 / OSL 512, --concurrency 10) reported TTFT p95 57,264ms / p99 57,401ms /
# max 57,627ms against a p50 of 704ms. Per-request records place the whole penalty in the
# opening concurrency wave -- the 10 requests issued at t=0 took 40.1-57.6s to first token
# and the remaining 90 took 0.60-1.38s -- so it is a cold-engine cost, and an EXCLUDED
# warmup phase is exactly what keeps it out of the report. It is also TTFT-only: those 10
# requests' ITL p50 was 114.89ms against 114.58ms for the other 90, which is why the
# warmup changes what the tail columns mean without moving the p50s (measured: TTFT p50
# 704.28 -> 703.28, ITL p50 114.58 -> 114.58, i.e. under 0.2%).
# 30 is kept rather than 10 (one wave was enough on that run) because 30 is the count
# already validated on NVFP4 and one constant is easier to reason about than two.
# Cost is wall-clock only: 30 excluded requests at --concurrency 10 add ~3 waves, ~180s
# on that ~650s run. What it does NOT fix is a hold that RECURS mid-run: the NVFP4
# lws-ep run of 2026-08-16 had 8 slow requests (TTFT > 2s) at t=224-261s, well past any
# warmup, and its worker logs carry no Triton JIT warning anywhere in that window - those
# requests were held on the prefill side. Always state the cutoff a slow-request count was
# taken at; the count is a function of the cut. Read that class with ./aiperf-clean-tail.sh
# over the export before quoting a TTFT mean or an upper percentile - its header carries
# the evidence and the prefill-side localisation.
# AIPERF_WARMUP_REQUESTS=0 disables, any integer overrides. Same idiom as WARMUP_ENABLED
# in the manifests -- note that one is still precision-gated, and gates the in-pod warmer,
# not the report.
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
# every topology in a folder shares one DEPLOYMENT_TYPE, so a lws-2pp run and the lws-pp2 run
# after it land in the same directory and aiperf truncates profile_export.jsonl on start. The
# per-request records of the earlier run are gone before its summary is read, and a repeat of
# the SAME topology (a cold run then a warm rerun) overwrites the summary too. Observed on
# p6-b200 2026-08-16: a completed disagg/lws-2pp report sat next to a zero-length
# profile_export.jsonl written by the disagg/lws-pp2 run started 97 minutes later.
# Scoping by MANIFEST_TYPE and run id keeps every run readable and comparable.
# AIPERF_RUN_ID can be set to any label (a ticket id, "cold", "warm") to name a run.
export AIPERF_RUN_ID="${AIPERF_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
export ARTIFACT_DIR="${MODEL_PATH}/aiperf/${DEPLOYMENT_TYPE}/${MANIFEST_TYPE}/${AIPERF_RUN_ID}"
echo "Artifacts: ${ARTIFACT_DIR}"

# Execute the aiperf command interactively
echo "Executing aiperf command in do-aiperf pod ..."

export CMD="kubectl ${_NS_ARG} exec -it do-aiperf -- aiperf profile --model \"${MODEL_NAME}\" --tokenizer \"${MODEL_PATH}\" --artifact-dir \"${ARTIFACT_DIR}\" --url \"${SERVICE_URL}\" --transport http --endpoint-type chat --streaming --concurrency 10 --request-count 100 ${_WARMUP_ARG} --synthetic-input-tokens-mean 1024 --synthetic-input-tokens-stddev 0 --output-tokens-mean 512 --extra-inputs \"ignore_eos:true\" --random-seed 42"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi

eval "${CMD}"

# Record what actually served this run, next to its report. ${MANIFEST_TYPE} names the artifact
# folder but nothing ever reads it back from the cluster, so a stale value in .env silently
# mislabels a report. Observed on p6-b200 2026-08-16: three folders under NVFP4
# .../disagg/lws-ep/ and .../disagg/deployment/ hold runs that were served by a
# DynamoGraphDeployment, not by the topology their path names. The runs were valid; only their
# labels were wrong, and telling them apart afterwards took a per-run metrics scrape.
#
# What is recorded, and what each field can actually prove:
#   frontend_pod   the Pod behind ${SERVICE_URL} when the run finished, resolved through the
#                  Service's EndpointSlice -- the process aiperf benchmarked. EndpointSlice and
#                  not `kubectl get endpoints`: the v1 Endpoints API is deprecated in k8s 1.33+
#                  and prints a warning on every call.
#   dyn_namespace  that Pod's DYN_NAMESPACE. It identifies a deployment independently of this
#                  folder and is the same label aiperf writes into server_metrics_export.json.
#                  It is NOT sufficient alone: agg/dgd, agg/dgd-v1beta1, agg/lws-ep, disagg/dgd
#                  and disagg/dgd-v1beta1 set no DYN_NAMESPACE, and dynamo defaults it to the
#                  literal "dynamo" (dynamo/common/utils/namespace.py), so an observed "dynamo"
#                  cannot by itself distinguish agg/lws from agg/lws-ep.
#   workloads      the owner of that Pod plus every workload labelled
#                  app.kubernetes.io/part-of=<deployment>. This is what does separate the
#                  topologies: one LeaderWorkerSet, a set of plain Deployments, or Deployments
#                  generated by a DynamoGraphDeployment.
#   label_check    compares the DYN_NAMESPACE the named template sets against the one observed,
#                  and says so plainly when the template sets none and the comparison proves
#                  nothing rather than reporting a pass it did not earn.
#
# Ordering is load-bearing: this runs AFTER the profile, because aiperf truncates its artifact
# directory on start, and BEFORE aiperf-pod-stop.sh, because the write goes through the
# do-aiperf pod -- the container that mounts the same /shared that ARTIFACT_DIR lives on.
#
# The model lives in ${NAMESPACE} (every template renders `namespace: ${NAMESPACE}`) and the
# do-aiperf pod now does too (aiperf-pod-run.sh passes it explicitly), so the deployment-side
# lookups and the write into do-aiperf below all use the same ${_NS_ARG} defined at the top of
# this script; empty NAMESPACE falls back to the context everywhere, consistently.
echo ""
echo "Recording run-meta.json ..."
_SVC="$(echo "${SERVICE_URL}" | sed -E 's#^[a-z]+://##; s#[:/].*$##; s#\..*$##')"
_PART_OF="${_SVC%-frontend}"
_FE_POD="$(kubectl ${_NS_ARG} get endpointslices -l "kubernetes.io/service-name=${_SVC}" -o jsonpath='{.items[0].endpoints[0].targetRef.name}' 2>/dev/null)"
_OBS_NS="$(kubectl ${_NS_ARG} exec "${_FE_POD}" -- printenv DYN_NAMESPACE 2>/dev/null | tr -d '\r\n')"
_FE_OWNER="$(kubectl ${_NS_ARG} get pod "${_FE_POD}" -o jsonpath='{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}' 2>/dev/null)"
_WORKLOADS="$(kubectl ${_NS_ARG} get deployments,statefulsets -l "app.kubernetes.io/part-of=${_PART_OF}" -o jsonpath='{range .items[*]}{.kind}/{.metadata.name} {end}' 2>/dev/null)"
_WORKLOADS="${_WORKLOADS}$(kubectl ${_NS_ARG} get leaderworkersets -l "app.kubernetes.io/part-of=${_PART_OF}" -o jsonpath='{range .items[*]}LeaderWorkerSet/{.metadata.name} {end}' 2>/dev/null)"
_DGDS="$(kubectl ${_NS_ARG} get dynamographdeployments -o jsonpath='{range .items[*]}{.metadata.name} {end}' 2>/dev/null)"

# Expected namespace for the topology this report claims to be, read from the template itself.
_TPL="../${DEPLOYMENT_TYPE}/${MANIFEST_TYPE}.yaml-template"
_EXP_NS="$(grep -m1 -o 'name: DYN_NAMESPACE, value: [A-Za-z0-9_-]*' "${_TPL}" 2>/dev/null | awk '{print $NF}')"
if [ ! -f "${_TPL}" ]; then
  _CHECK="unverified: ${_TPL} not found from $(pwd), so the asserted topology could not be read"
elif [ "${_EXP_NS}" == "" ]; then
  # Single quotes around the values, not double: _CHECK lands inside a JSON string in the
  # heredoc below, and a literal double quote there makes the whole run-meta.json unparsable.
  # Both 2026-08-17 dgd runs shipped malformed run-meta.json through this branch.
  _CHECK="not discriminating: ${MANIFEST_TYPE}.yaml-template sets no DYN_NAMESPACE, dynamo defaults it to 'dynamo', observed '${_OBS_NS}' -- use the workloads field to identify this run"
elif [ "${_EXP_NS}" == "${_OBS_NS}" ]; then
  _CHECK="consistent: ${MANIFEST_TYPE} sets DYN_NAMESPACE=${_EXP_NS} and the serving frontend reports ${_OBS_NS}"
else
  _CHECK="MISMATCH: ${MANIFEST_TYPE} sets DYN_NAMESPACE=${_EXP_NS} but the serving frontend reports '${_OBS_NS}' -- this report is in the wrong folder"
fi

# Emit the warm-up count as a JSON number only when it is one. The gate above accepts any value
# for AIPERF_WARMUP_REQUESTS (`[ ... -gt 0 ] 2>/dev/null` just treats a non-integer as 0), so a
# typo there must not be able to produce a run-meta.json that will not parse.
case "${_WARMUP_COUNT}" in
  ''|*[!0-9]*) _WARMUP_JSON="\"${_WARMUP_COUNT}\"" ;;
  *)           _WARMUP_JSON="${_WARMUP_COUNT}" ;;
esac

kubectl ${_NS_ARG} exec -i do-aiperf -- sh -c "mkdir -p '${ARTIFACT_DIR}' && cat > '${ARTIFACT_DIR}/run-meta.json'" <<EOF
{
  "run_id": "${AIPERF_RUN_ID}",
  "recorded_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "asserted": {
    "deployment_type": "${DEPLOYMENT_TYPE}",
    "manifest_type": "${MANIFEST_TYPE}",
    "model_name": "${MODEL_NAME}",
    "model_path": "${MODEL_PATH}",
    "service_url": "${SERVICE_URL}",
    "warmup_requests": ${_WARMUP_JSON}
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
