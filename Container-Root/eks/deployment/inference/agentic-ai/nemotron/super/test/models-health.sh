#!/bin/bash

# Run a curl pod and send a request to the /health endpoint

source .env

# -t only when stdin is a terminal: from a script or CI there is no TTY, `kubectl run -it` then fails to
# attach ("Unable to use a TTY" + "couldn't attach to pod") and the response is lost.
_TTY=""; if [ -t 0 ]; then _TTY="t"; fi

export CMD="kubectl run -i${_TTY} --rm do-curl --image iankoulski/do-curl --restart Never -- bash -c \"curl ${SERVICE_URL}/health | jq .\""

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi

eval "${CMD}"
