#!/bin/bash

. .env

docker run -it --rm --gpus all --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 ${REGISTRY}${IMAGE}${TAG} bash
