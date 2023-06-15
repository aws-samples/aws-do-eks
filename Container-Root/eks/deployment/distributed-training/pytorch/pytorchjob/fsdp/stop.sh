#!/bin/bash

kubectl delete -f ./fsdp.yaml

kubectl delete pod $(kubectl get pod | grep etcd | cut -d ' ' -f 1)

