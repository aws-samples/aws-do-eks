#!/bin/bash

source .env

kubectl -n ${NAMESPACE} logs -f $(kubectl get pods | grep aiperf-sweep | cut -d ' ' -f 1)

