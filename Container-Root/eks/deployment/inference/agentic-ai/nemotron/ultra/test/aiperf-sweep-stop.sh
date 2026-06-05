#!/bin/bash

source .env

kubectl -n ${NAMESPACE} delete pod $(kubectl get pods | grep aiperf-sweep | cut -d ' ' -f 1)

