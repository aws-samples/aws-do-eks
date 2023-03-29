#!/bin/bash

ext=gpu
if [ ! "$1" == "" ]; then
	ext=$1
fi

kubectl apply -f ./imagenet-${ext}.yaml

