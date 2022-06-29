#!/bin/bash

echo ""
echo "Deleting persistent volume ..."
kubectl delete -f ./efs-pv.yaml

echo ""
echo "Deleting storage class ..."
kubectl delete -f ./efs-sc.yaml

echo ""
echo "Deleting EFS CSI driver ..."
kubectl delete -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.3"

echo ""
echo "Done."
echo "If you wish to also delete the EFS Filesystem, execute ./efs-delete.sh"
echo ""
