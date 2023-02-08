#!/bin/bash

source .env

docker image push ${REGISTRY}${IMAGE}${TAG}

