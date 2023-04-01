#!/bin/bash

source .env

ext=cpu
if [ ! "$1" == "" ]; then
	ext=$1
fi

kubectl logs -f $(kubectl get pods | grep launcher | grep $ext | cut -d ' ' -f 1)

