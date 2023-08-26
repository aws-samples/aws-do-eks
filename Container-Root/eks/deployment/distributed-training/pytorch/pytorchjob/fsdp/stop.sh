#!/bin/bash

. .env

kubectl delete -f ./fsdp.yaml

kubectl delete pod $(kubectl get pod | grep $RDZV_HOST | cut -d ' ' -f 1)

