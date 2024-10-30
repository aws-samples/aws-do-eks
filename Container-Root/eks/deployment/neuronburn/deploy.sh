#!/bin/bash

ext=trn
if [ ! "$1" == "" ]; then
	ext=$1
fi

kubectl apply -f ./neuronburn-daemonset-${ext}.yaml

