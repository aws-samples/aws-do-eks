#!/bin/bash

source .env

echo ""
echo "Starting app:"
APP=$(torchx run --scheduler kubernetes --scheduler_args namespace=default,queue=default,image_repo=${REGISTRY}${IMAGE} --workspace="" utils.echo --image alpine:latest --msg hello)

sleep 3

echo ""
echo "Status:"
torchx status $APP

