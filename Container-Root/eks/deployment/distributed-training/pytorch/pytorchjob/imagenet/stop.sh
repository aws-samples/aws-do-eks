#!/bin/bash

ext=gpu
if [ ! "$1" == "" ]; then
	ext=$1
fi

kubectl delete -f ./imagenet-${ext}.yaml

kubectl delete pod $(kubectl get pod | grep etcd | cut -d ' ' -f 1)

