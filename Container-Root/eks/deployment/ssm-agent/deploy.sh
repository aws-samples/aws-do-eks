#!/bin/bash

# Reference: https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/install-ssm-agent-on-amazon-eks-worker-nodes-by-using-kubernetes-daemonset.html

echo ""
echo "Deploying SSM Agent daemonset ..."

kubectl apply -f ./ssm-daemonset.yaml


