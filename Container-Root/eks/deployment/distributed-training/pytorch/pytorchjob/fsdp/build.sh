#!/bin/bash

. .env

docker build -t ${REGISTRY}${IMAGE}${TAG} -f Dockerfile .

