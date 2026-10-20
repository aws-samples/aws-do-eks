#!/bin/bash

# Deploy the NVIDIA Dynamo platform (operator, CRDs, etcd, NATS) on a clean EKS cluster.
# Ref: https://docs.nvidia.com/dynamo/kubernetes-deployment/deployment-guide/quickstart
#
# Assumes a vanilla cluster (GPU/EFA device plugins, FSx CSI, LWS CRD already installed).
# Fresh-install only: to move between Dynamo versions run ./remove.sh first, then this.
# In-place upgrades are not supported (etcd 3.5->3.6 data-dir and kai-scheduler CRD conflicts).

export DYNAMO_NAMESPACE=${DYNAMO_NAMESPACE:-dynamo-system}
export DYNAMO_VERSION=${DYNAMO_VERSION:-"1.5.1"}

# 1.5.1 needs no CRD pre-apply. The PodSnapshot/PodSnapshotContent CRDs the 1.3.x/1.4.0 operator
# reconciled are no longer under deploy/operator/config/crd/bases at the v1.5.1 tag (the raw URLs
# the 1.4.0 version of this script applied now return 404): they ship in the chart's new standalone
# `snapshot` subchart (global.snapshot.install, default false - checkpoint/restore stays off in
# values.yaml) and the operator chart installs its own CRDs (dynamo-operator.crdInstaller.enabled=true).

helm fetch https://helm.ngc.nvidia.com/nvidia/ai-dynamo/charts/dynamo-platform-${DYNAMO_VERSION}.tgz

helm upgrade --install dynamo-platform dynamo-platform-${DYNAMO_VERSION}.tgz --namespace "$DYNAMO_NAMESPACE" --create-namespace -f values.yaml

# Verify: Running is not started - wait for the operator rollout and the data plane to be Ready.
kubectl -n "$DYNAMO_NAMESPACE" rollout status deploy/dynamo-platform-dynamo-operator-controller-manager --timeout=300s
kubectl -n "$DYNAMO_NAMESPACE" wait pod dynamo-platform-etcd-0 --for=condition=Ready --timeout=300s
kubectl -n "$DYNAMO_NAMESPACE" wait pod dynamo-platform-nats-0 --for=condition=Ready --timeout=300s

echo ""
echo "Dynamo CRDs:"
kubectl get crd | grep "nvidia.com" | grep -E "dynamo|podsnapshot|snapshotjob"
echo ""
kubectl -n "$DYNAMO_NAMESPACE" get pods
