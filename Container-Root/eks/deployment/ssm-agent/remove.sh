#!/bin/bash

echo ""
echo "Removing SSM Agent daemonset ..."
echo "SSM Agent will not be installed on new nodes, it will continue to run on existing nodes"

kubectl delete -f ./ssm-daemonset.yaml

