#!/bin/bash

# Ref: https://github.com/iankoulski/do-aiperf

if [ -f ./.env ]; then source ./.env; fi

# The pod must land in ${NAMESPACE} -- the namespace fsx-pvc and the model live in -- not in
# whatever namespace the kubeconfig's current context points at. A context pinned to another
# namespace (e.g. an admin context on kube-system) otherwise creates the pod where fsx-pvc
# does not exist: it sits Pending on 'persistentvolumeclaim "fsx-pvc" not found' with no host
# assigned, and the FailedScheduling event is invisible from the namespace you are watching.
_NS_ARG=""
if [ "${NAMESPACE}" != "" ]; then _NS_ARG="-n ${NAMESPACE}"; fi

echo ""
AIPERF_POD_NAME="${AIPERF_POD_NAME:-do-aiperf}"
echo "Starting ${AIPERF_POD_NAME} pod ..."

# karpenter.sh/do-not-disrupt: on an EKS Auto Mode cluster the utility NodePool consolidates
# `WhenEmptyOrUnderutilized` after 30 s and drains nodes under live pods. A drain evicted a running
# do-aiperf pod mid-run (exit 137, no export) on 2026-10-19; the annotation makes Karpenter leave
# this pod's node alone while it exists. Inert on clusters without Karpenter.
export CMD="kubectl ${_NS_ARG} run ${AIPERF_POD_NAME} --image=iankoulski/do-aiperf --overrides='{\"metadata\": {\"annotations\": {\"karpenter.sh/do-not-disrupt\": \"true\"}}, \"spec\": {\"containers\": [{\"name\": \"do-aiperf\", \"image\": \"iankoulski/do-aiperf\", \"volumeMounts\": [{\"name\": \"fsx-vol\", \"mountPath\": \"/shared\"}]}], \"volumes\": [{\"name\": \"fsx-vol\", \"persistentVolumeClaim\": {\"claimName\": \"fsx-pvc\"}}]}}'"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi

eval "${CMD}"
