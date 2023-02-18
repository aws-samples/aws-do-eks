#!/bin/bash

source .env

docker build -t ${REGISTRY}${IMAGE}:latest -f Dockerfile .

docker build -t ${REGISTRY}${IMAGE}:mpi -f Dockerfile-mpi .


