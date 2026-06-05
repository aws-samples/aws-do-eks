#!/bin/bash

# Run a curl pod and send a request to the /v1/chat/completions endpoint

source .env

LLM_PROMPT=${1:-"Hello, give me a one sentence status."}
API_URL="${SERVICE_URL}/v1/chat/completions"

# Write request body to a variable with no quoting conflicts
read -r -d '' REQUEST_BODY << EOF
{"model":"${MODEL_NAME}","messages": [ { "role": "user", "content": "${LLM_PROMPT}" } ], "max_tokens":128, "temperature": 0.2}
EOF

# Base64 encode to completely avoid quoting issues
B64_BODY=$(echo -n "$REQUEST_BODY" | base64 -w0)

CURL_CMD="echo $B64_BODY | base64 -d | curl -s $API_URL -H 'Content-Type: application/json' -d @- | jq ."

if [ "$verbose" != "false" ]; then echo -e "\n${CURL_CMD}\n"; fi

kubectl run -it --rm do-curl --image=iankoulski/do-curl --restart=Never -- bash -c "$CURL_CMD"

