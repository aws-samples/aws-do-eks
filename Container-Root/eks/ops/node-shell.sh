#!/bin/bash

if [ "$1" == "" ]; then
	echo ""
	echo "Please specify node name or unique part of a node name as argument"
else
	kubectl node-shell $(kubectl get nodes | grep $1 | cut -d ' ' -f 1)
fi	

