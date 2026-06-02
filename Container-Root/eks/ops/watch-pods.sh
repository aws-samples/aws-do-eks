#!/bin/bash

if [ "$2" == "" ]; then
	if [ "$1" == "" ]; then
		watch "kubectl get pods"
	else
		watch "kubectl get pods | grep $1"
	fi
else	
	watch kubectl get pods "$@"
fi

