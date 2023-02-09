#!/bin/bash

source .env

if [ "$TO" == "kubernetes" ]; then
  if [ "$1" == "" ]; then
    POD=$(kubectl get pods | grep ${CONTAINER} | cut -d ' ' -f 1)
  else
    POD=$(kubectl get pods | grep $1 | head -n 1 | cut -d ' ' -f 1)
  fi
  kubectl logs -f $POD
else
  docker container logs -f ${CONTAINER}
fi

