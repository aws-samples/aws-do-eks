#!/bin/bash

# Run a curl pod and send a request to the /health endpoint

source .env

export CMD="kubectl run -it --rm do-curl --image iankoulski/do-curl --restart Never -- bash -c \"curl ${SERVICE_URL}/health | jq .\""

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi

eval "${CMD}"
