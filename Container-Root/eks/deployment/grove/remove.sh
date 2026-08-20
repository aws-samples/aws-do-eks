#!/bin/bash

# Remove Grove and the KAI scheduler and return the cluster to its pre-deploy state.
# Counterpart of ./deploy.sh.

export GROVE_NAMESPACE=${GROVE_NAMESPACE:-grove-system}
export KAI_NAMESPACE=${KAI_NAMESPACE:-kai-scheduler}
export DYNAMO_NAMESPACE=${DYNAMO_NAMESPACE:-dynamo-system}

# 1. Flip Grove/KAI integration off on the Dynamo platform first, so the Dynamo operator stops
#    reconciling PodCliqueSets before their CRDs disappear.
DYNAMO_CHART_VERSION=$(helm list -n "$DYNAMO_NAMESPACE" -f '^dynamo-platform$' -o json 2>/dev/null \
    | python3 -c 'import sys,json; r=json.load(sys.stdin); print(r[0]["chart"].removeprefix("dynamo-platform-") if r else "")')
if [ -n "$DYNAMO_CHART_VERSION" ]; then
    helm upgrade dynamo-platform \
        "https://helm.ngc.nvidia.com/nvidia/ai-dynamo/charts/dynamo-platform-${DYNAMO_CHART_VERSION}.tgz" \
        -n "$DYNAMO_NAMESPACE" --reuse-values \
        --set global.grove.enabled=false \
        --set global.kai-scheduler.enabled=false
    kubectl -n "$DYNAMO_NAMESPACE" rollout status deploy/dynamo-platform-dynamo-operator-controller-manager --timeout=300s
fi

# 2. Delete Grove custom resources first so finalizers run while the Grove operator is alive.
for CRD in $(kubectl get crd -o name | grep -E "grove.io"); do
    RESOURCE=$(basename $CRD | cut -d. -f1)
    kubectl delete $RESOURCE --all -A --ignore-not-found --timeout=120s
done

# 3. Uninstall both releases.
helm delete grove -n "$GROVE_NAMESPACE" --ignore-not-found
helm delete kai-scheduler -n "$KAI_NAMESPACE" --ignore-not-found

# 4. Delete the CRDs (helm leaves chart-crds/ CRDs behind by design). Grove groups: grove.io +
#    scheduler.grove.io. KAI groups: kai.scheduler + scheduling.run.ai.
kubectl get crd -o name | grep -E "grove.io|kai.scheduler|scheduling.run.ai" | xargs -r kubectl delete

# 5. Namespaces.
kubectl delete namespace "$GROVE_NAMESPACE" --ignore-not-found --timeout=120s
kubectl delete namespace "$KAI_NAMESPACE" --ignore-not-found --timeout=120s

# 6. Verify zero residue - all of the following should print nothing.
echo ""
echo "Verifying removal (all of the following should be empty):"
kubectl get crd | grep -E "grove.io|kai.scheduler|scheduling.run.ai"
kubectl get namespace "$GROVE_NAMESPACE" 2>/dev/null
kubectl get namespace "$KAI_NAMESPACE" 2>/dev/null
helm list -A 2>/dev/null | grep -E "^grove|^kai-scheduler"
echo "Done."
