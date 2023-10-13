#!/bin/bash

./generate.sh

kubectl apply -f ./etcd.yaml
kubectl apply -f ./fsdp.yaml

