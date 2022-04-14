#!/bin/bash

if [ -f /aws-do-eks/.env ]; then
    pushd /aws-do-eks
else
    pushd ../../../../
fi
source .env
popd

if [ -z $REGISTRY ]; then
    echo 'REGISTRY not defined in .env file. Exiting.'
    exit
else
    echo 'Using' $REGISTRY
fi

# create new namespace
# kubectl apply -f cloudwatch-namespace.yaml
kubectl create namespace amazon-cloudwatch
kubectl config set-context --current --namespace=amazon-cloudwatch
kubectl apply -f cwagent-serviceaccount.yaml

# set configmap
kubectl apply -f cwagent-configmap.yaml

# create the daemonset
cat ./cwagent-daemonset-template.yaml | sed -e "s#<DOCKER_REGISTRY>#$REGISTRY#g" > cwagent-daemonset.yaml
kubectl apply -f cwagent-daemonset.yaml
kubectl get pods
