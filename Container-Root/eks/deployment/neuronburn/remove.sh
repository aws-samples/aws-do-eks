#!/bin/bash

ext=trn
if [ ! "$1" == "" ]; then
	ext=$1
fi

kubectl delete -f ./neuronburn-daemonset-${ext}.yaml

