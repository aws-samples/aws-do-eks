#!/bin/bash

source .env

if [ "$TO" == "kubernetes" ]; then
  kubectl get pods -o wide | grep ${CONTAINER}
else
  docker ps -a | grep ${CONTAINER}
fi

