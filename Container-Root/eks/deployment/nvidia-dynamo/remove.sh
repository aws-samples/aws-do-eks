#!/bin/bash

# Remove the NVIDIA Dynamo platform and return the cluster to its pre-deploy state.
# Ref: https://docs.nvidia.com/dynamo/kubernetes-deployment/deployment-guide

export DYNAMO_NAMESPACE=${DYNAMO_NAMESPACE:-dynamo-system}

# 1. Delete all Dynamo custom resources first so their finalizers run while the operator is alive.
for CRD in $(kubectl get crd -o name | grep "nvidia.com" | grep -E "dynamo|podsnapshot"); do
    RESOURCE=$(basename $CRD | cut -d. -f1)
    kubectl delete $RESOURCE --all -A --ignore-not-found --timeout=120s
done

# 2. Uninstall the platform release (operator, etcd, NATS).
helm delete dynamo-platform -n $DYNAMO_NAMESPACE

# 3. Delete the Dynamo CRDs. Match both groups: dynamo*.nvidia.com AND podsnapshot*.nvidia.com -
#    a bare "dynamo" grep leaves the two podsnapshot CRDs behind.
kubectl get crd -o name | grep "nvidia.com" | grep -E "dynamo|podsnapshot" | xargs -r kubectl delete

# 4. Delete the PVCs helm leaves behind (etcd data, NATS JetStream), then the namespace.
kubectl delete pvc --all -n $DYNAMO_NAMESPACE --ignore-not-found --timeout=120s
kubectl delete namespace $DYNAMO_NAMESPACE --ignore-not-found --timeout=120s

# 5. Verify zero residue - all four checks should print nothing.
echo ""
echo "Verifying removal (all of the following should be empty):"
kubectl get crd | grep "nvidia.com" | grep -E "dynamo|podsnapshot"
kubectl get namespace $DYNAMO_NAMESPACE 2>/dev/null
helm list -n $DYNAMO_NAMESPACE 2>/dev/null | grep dynamo-platform
kubectl get pv 2>/dev/null | grep $DYNAMO_NAMESPACE
echo "Done."
