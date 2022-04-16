#!/bin/bash

kubectl config set-context --current --namespace=amazon-cloudwatch

kubectl delete -f cwagent-daemonset.yaml
kubectl delete -f cwagent-configmap.yaml
kubectl delete -f cwagent-serviceaccount.yaml
