#!/bin/bash

kubectl delete -f efs-share-test.yaml
sleep 5

kubectl delete -f efs-pvc.yaml
sleep 5

kubectl delete -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.3"
