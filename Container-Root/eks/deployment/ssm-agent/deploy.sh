#!/bin/bash

echo ""
echo "Deploying SSM Agent daemonset ..."

kubectl apply -f ./ssm-daemonset.yaml


