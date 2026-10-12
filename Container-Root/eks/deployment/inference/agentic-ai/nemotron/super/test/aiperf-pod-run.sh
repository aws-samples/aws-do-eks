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
echo "Starting do-aiperf pod ..."

export CMD="kubectl ${_NS_ARG} run do-aiperf --image=iankoulski/do-aiperf --overrides='{\"spec\": {\"nodeSelector\": {\"nvidia.com/gpu.present\": \"true\"}, \"containers\": [{\"name\": \"do-aiperf\", \"image\": \"iankoulski/do-aiperf\", \"volumeMounts\": [{\"name\": \"fsx-vol\", \"mountPath\": \"/shared\"}]}], \"volumes\": [{\"name\": \"fsx-vol\", \"persistentVolumeClaim\": {\"claimName\": \"fsx-pvc\"}}]}}'"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi

eval "${CMD}"
