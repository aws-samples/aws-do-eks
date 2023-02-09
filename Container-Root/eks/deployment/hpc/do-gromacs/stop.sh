#!/bin/bash

source .env

if [ "$TO" == "docker" ]; then
	docker container rm -f ${CONTAINER}
elif [ "$TO" == "kubernetes" ]; then
	ls to/kubernetes/app/*.yaml | grep namespace | xargs rm -vf
	ls to/kubernetes/app/*.yaml | grep pvc | xargs rm -vf
	for m in $(ls to/kubernetes/app/*.yaml | sort -r) ; do echo Deleting $m ...; kubectl delete -f $m; done
else
	echo ""
	echo "Unknonwn Target Orchestrator $TO"
fi
echo ""

