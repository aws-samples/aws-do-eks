#!/bin/bash

source .env

kubectl -n ${NAMESPACE} cp -f $(kubectl get pods | grep aiperf-sweep | cut -d ' ' -f 1):/tmp/run-bundle/summary.json ./sweep-summary.json

cat ./aiperf-sweep-summary.json

