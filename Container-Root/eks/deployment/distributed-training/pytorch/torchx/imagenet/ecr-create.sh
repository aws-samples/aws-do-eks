#!/bin/bash

source .env

REGISTRY_COUNT=$(aws ecr describe-repositories | grep ${IMAGE} | wc -l)
if [ "$REGISTRY_COUNT" == "0" ]; then
	echo "Creating registry ${IMAGE} ..." 
	aws ecr create-repository --repository-name ${IMAGE}
else
	echo "Registry ${IMAGE} already exists."
fi

