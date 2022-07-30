#!/bin/bash

if [ -f /aws-do-eks/.env ]; then
    pushd /aws-do-eks
else
    pushd ../../../../../../../
fi
source .env
popd

echo ""
echo "Generating pod manifest ..."
cat deepspeed-bert.yaml.template | sed -e "s@\${REGISTRY}@${REGISTRY}@g" > deepspeed-bert.yaml

echo ""
echo "Creating deepspeed-bert pod ..."
kubectl apply -f deepspeed-bert.yaml
sleep 3
kubectl get pods | grep deepspeed-bert

