#!/bin/bash

# Deploy NVIDIA Grove (multinode orchestration via PodCliqueSets) and the KAI scheduler
# (gang scheduling) as STANDALONE releases, then enable Grove integration on an existing
# Dynamo platform release if one is present.
# Refs: https://github.com/ai-dynamo/grove  https://github.com/NVIDIA/KAI-Scheduler
#
# Installed separately (not via the dynamo-platform bundled subcharts) per the chart's own
# guidance: "For production environments, it is recommended to install Grove separately."
# Versions default to the pair the dynamo-platform 1.4.0 Chart.lock ships, so the combination
# is the one NVIDIA tests together. Override with GROVE_VERSION / KAI_VERSION.

export GROVE_NAMESPACE=${GROVE_NAMESPACE:-grove-system}
export GROVE_VERSION=${GROVE_VERSION:-"v0.1.0-alpha.12-rc1"}
export KAI_NAMESPACE=${KAI_NAMESPACE:-kai-scheduler}
export KAI_VERSION=${KAI_VERSION:-"v0.13.4"}
export DYNAMO_NAMESPACE=${DYNAMO_NAMESPACE:-dynamo-system}

# 1. KAI scheduler first: Grove PodGangs schedule best with gang scheduling available.
helm upgrade --install kai-scheduler oci://ghcr.io/kai-scheduler/kai-scheduler/kai-scheduler \
    --version "$KAI_VERSION" --namespace "$KAI_NAMESPACE" --create-namespace -f values-kai.yaml

# 2. Grove operator (grove.io + scheduler.grove.io CRDs ship in the chart's crds/ dir and
#    install with it).
helm upgrade --install grove oci://ghcr.io/ai-dynamo/grove/grove-charts \
    --version "$GROVE_VERSION" --namespace "$GROVE_NAMESPACE" --create-namespace -f values-grove.yaml

kubectl -n "$KAI_NAMESPACE" wait pods --all --for=condition=Ready --timeout=300s
kubectl -n "$GROVE_NAMESPACE" rollout status deploy/grove-operator --timeout=300s

# 3. If a Dynamo platform release exists, flip its Grove/KAI integration on so the Dynamo
#    operator creates PodCliqueSets for multinode DynamoGraphDeployments. The chart version is
#    read from the live release so this never moves the platform version. Safe to re-run.
DYNAMO_CHART_VERSION=$(helm list -n "$DYNAMO_NAMESPACE" -f '^dynamo-platform$' -o json 2>/dev/null \
    | python3 -c 'import sys,json; r=json.load(sys.stdin); print(r[0]["chart"].removeprefix("dynamo-platform-") if r else "")')
if [ -n "$DYNAMO_CHART_VERSION" ]; then
    echo "Enabling Grove + KAI integration on dynamo-platform-$DYNAMO_CHART_VERSION in $DYNAMO_NAMESPACE ..."
    helm upgrade dynamo-platform \
        "https://helm.ngc.nvidia.com/nvidia/ai-dynamo/charts/dynamo-platform-${DYNAMO_CHART_VERSION}.tgz" \
        -n "$DYNAMO_NAMESPACE" --reuse-values \
        --set global.grove.enabled=true \
        --set global.kai-scheduler.enabled=true
    kubectl -n "$DYNAMO_NAMESPACE" rollout status deploy/dynamo-platform-dynamo-operator-controller-manager --timeout=300s
else
    echo "No dynamo-platform release in $DYNAMO_NAMESPACE - skipping integration flip."
    echo "After deploying Dynamo, re-run this script or set global.grove.enabled=true on that release."
fi

echo ""
echo "Grove CRDs:"
kubectl get crd | grep -E "grove.io"
echo ""
echo "KAI CRDs:"
kubectl get crd | grep -E "kai.scheduler|scheduling.run.ai"
echo ""
kubectl -n "$GROVE_NAMESPACE" get pods
kubectl -n "$KAI_NAMESPACE" get pods
