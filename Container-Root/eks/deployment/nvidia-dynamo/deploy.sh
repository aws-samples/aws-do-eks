#!/bin/bash

# Deploy the NVIDIA Dynamo platform (operator, CRDs, etcd, NATS) on a clean EKS cluster.
# Ref: https://docs.nvidia.com/dynamo/kubernetes-deployment/deployment-guide/quickstart
#
# Assumes a vanilla cluster (GPU/EFA device plugins, FSx CSI, LWS CRD already installed).
# Fresh-install only: to move between Dynamo versions run ./remove.sh first, then this.
# In-place upgrades are not supported (etcd 3.5->3.6 data-dir and kai-scheduler CRD conflicts).

export DYNAMO_NAMESPACE=${DYNAMO_NAMESPACE:-dynamo-system}
export DYNAMO_VERSION=${DYNAMO_VERSION:-"1.3.1"}

# The 1.3.x operator reconciles PodSnapshot/PodSnapshotContent but the chart tarball does not
# ship those two CRDs (they normally come from a crd-apply init container). Apply them from the
# matching upstream tag first so the operator can never CrashLoop on a missing restmapping.
# This is additive and idempotent - existing CRDs are left as-is.
for CRD in podsnapshotcontents podsnapshots; do
    kubectl apply -f https://raw.githubusercontent.com/ai-dynamo/dynamo/v${DYNAMO_VERSION}/deploy/operator/config/crd/bases/nvidia.com_${CRD}.yaml
done

helm fetch https://helm.ngc.nvidia.com/nvidia/ai-dynamo/charts/dynamo-platform-${DYNAMO_VERSION}.tgz

helm upgrade --install dynamo-platform dynamo-platform-${DYNAMO_VERSION}.tgz --namespace "$DYNAMO_NAMESPACE" --create-namespace -f values.yaml

# Verify: Running is not started - wait for the operator rollout and the data plane to be Ready.
kubectl -n "$DYNAMO_NAMESPACE" rollout status deploy/dynamo-platform-dynamo-operator-controller-manager --timeout=300s
kubectl -n "$DYNAMO_NAMESPACE" wait pod dynamo-platform-etcd-0 --for=condition=Ready --timeout=300s
kubectl -n "$DYNAMO_NAMESPACE" wait pod dynamo-platform-nats-0 --for=condition=Ready --timeout=300s

echo ""
echo "Dynamo CRDs:"
kubectl get crd | grep "nvidia.com" | grep -E "dynamo|podsnapshot"
echo ""
kubectl -n "$DYNAMO_NAMESPACE" get pods
