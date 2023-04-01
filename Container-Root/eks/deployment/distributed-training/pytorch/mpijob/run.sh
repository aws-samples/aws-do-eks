#!/bin/bash

source .env

export ext=cpu
if [ ! "$1" == "" ]; then
	export ext=$1
fi

cat ./imagenet-${ext}.yaml-template | envsubst > ./imagenet-${ext}.yaml

kubectl apply -f ./imagenet-${ext}.yaml

