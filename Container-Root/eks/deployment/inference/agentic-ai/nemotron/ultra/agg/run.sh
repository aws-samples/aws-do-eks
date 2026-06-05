#!/bin/bash

source .env

cat deployment.yaml-template | envsubst > deployment.yaml

kubectl apply -f ./deployment.yaml

