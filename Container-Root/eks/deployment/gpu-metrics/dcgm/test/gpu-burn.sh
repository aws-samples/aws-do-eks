#!/bin/bash

# This script executes gpu_burn within the first gpu-burn pod it finds in the default namespace

burn_time=$1
if [ "$burn_time" == "" ]; then
	burn_time=30
fi

kubectl -n default exec $(kubectl -n default get po | grep gpu-burn | head -n 1 | cut -d ' ' -f 1) -- /root/gpu_burn $burn_time

