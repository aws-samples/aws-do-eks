#!/bin/bash

source .env

cat aiperf-sweep.yaml-template | envsubst > aiperf-sweep.yaml

kubectl apply -f ./aiperf-sweep.yaml


