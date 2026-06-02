#!/bin/bash

if [ "$2" == "" ]; then
	if [ "$1" == "" ]; then
		watch "kubectl get pods -o wide"
	else
		watch "kubectl get pods -o wide | grep $1"
	fi
else	
	watch kubectl get pods -o wide "$@"
fi

