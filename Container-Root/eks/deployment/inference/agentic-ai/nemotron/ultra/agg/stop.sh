#!/bin/bash

source .env

cat deployment.yaml-template | envsubst > deployment.yaml

kubectl delete -f ./deployment.yaml

kubectl delete pods $(kubectl get pods | grep ${DEPLOYMENT_NAME} | cut -d ' ' -f 1)

