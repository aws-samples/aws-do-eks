#!/bin/bash

if [ -f /aws-do-eks/.env ]; then
    pushd /aws-do-eks
else
    pushd ../../../../../../
fi
source .env
popd

echo ""
echo "Generating pod manifest ..."
cat mpijob-mnist.yaml.template | sed -e "s@\${REGISTRY}@${REGISTRY}@g" > mpijob-mnist.yaml

echo ""
echo "Creating pod ..."
kubectl apply -f mpijob-mnist.yaml
sleep 3
kubectl get pods | grep mnist

