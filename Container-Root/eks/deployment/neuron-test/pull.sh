#!/bin/bash

source .env

docker image pull ${REGISTRY}${IMAGE}${TAG}

