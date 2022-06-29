#!/bin/bash

echo ""
echo "Deploying EFS Share test pvc and pod ..."
kubectl apply -f ./efs-pvc.yaml
kubectl apply -f ./efs-share-test.yaml
sleep 3
kubectl get pvc
kubectl get pods | grep test

echo ""
echo "The EFA Share test is successful If the efs-share-test pod enters the Running state."
echo "If the pod does not enter the Running state, execute 'kubectl describe pod efs-share-test' to debug."
echo ""
