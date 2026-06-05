#!/bin/bash

# Run a curl pod and send a request to the /v1/models endpoin

source .env

CMD="kubectl run -it --rm do-curl --image iankoulski/do-curl --restart Never -- bash -c \"curl ${SERVICE_URL}/v1/models | jq .\""

if [ ! "$verbose" == "false" ]; then
	echo -e "\n${CMD}\n"
fi

eval "${CMD}"

