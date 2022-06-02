#!/bin/bash

echo ""
echo "Deleting EFS Share test pod and pvc ..."
kubectl delete -f ./efs-share-test.yaml
kubectl delete -f ./efs-pvc.yaml

echo "Releasing PV efs-pv ..."
kubectl patch pv efs-pv -p '{"spec":{"claimRef": null}}'
