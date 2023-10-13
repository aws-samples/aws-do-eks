#!/bin/bash

if [ "$1" == "" ]; then
	kubectl describe nodes
else
	kubectl describe nodes $(kubectl get nodes | grep $1 | cut -d ' ' -f 1)
fi	

