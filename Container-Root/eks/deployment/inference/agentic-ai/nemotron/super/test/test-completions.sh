#!/bin/bash

# Run a curl pod and send a request to the /v1/completions endpoint

source .env

# -t only when stdin is a terminal: from a script or CI there is no TTY, `kubectl run -it` then fails to
# attach ("Unable to use a TTY" + "couldn't attach to pod") and the response is lost.
_TTY=""; if [ -t 0 ]; then _TTY="t"; fi

LLM_PROMPT=${1:-"Hello, how are you?"}
API_URL="${SERVICE_URL}/v1/completions"

# Write request body to a variable with no quoting conflicts
read -r -d '' REQUEST_BODY << EOF
{"model":"${MODEL_NAME}","prompt":"${LLM_PROMPT}","max_tokens":128,"temperature":0.2}
EOF

echo ""
echo "${REQUEST_BODY}"
echo ""

# Base64 encode to completely avoid quoting issues
B64_BODY=$(echo -n "$REQUEST_BODY" | base64 -w0)

CURL_CMD="echo $B64_BODY | base64 -d | curl -s $API_URL -H 'Content-Type: application/json' -d @- | jq ."

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CURL_CMD}\n"; fi

export CMD="kubectl run -i${_TTY} --rm do-curl --image=iankoulski/do-curl --restart=Never -- bash -c \"$CURL_CMD\""

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi

eval "${CMD}"
