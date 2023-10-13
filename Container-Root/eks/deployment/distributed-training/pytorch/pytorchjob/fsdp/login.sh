#!/bin/bash

. .env

if [ ! "$1" == "" ]; then
	REGISTRY=$1
fi

# Login to registry
echo ""
echo "Logging in to $REGISTRY ..."
aws ecr get-login-password | docker login --username AWS --password-stdin $REGISTRY


