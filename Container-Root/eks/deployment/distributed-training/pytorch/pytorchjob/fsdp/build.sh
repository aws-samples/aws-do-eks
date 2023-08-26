#!/bin/bash

. .env

#docker build --no-cache --progress=plain -t ${REGISTRY}${IMAGE}${TAG} -f Dockerfile .
docker build --progress=plain -t ${REGISTRY}${IMAGE}${TAG} -f Dockerfile.$FI_PROVIDER .

