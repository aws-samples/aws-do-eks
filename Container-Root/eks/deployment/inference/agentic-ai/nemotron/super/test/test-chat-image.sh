#!/bin/bash

# Run a curl pod and send ONE image prompt to the /v1/chat/completions endpoint.
# This is the single-request vision smoke: a public image URL goes in as image_url
# content (the same request shape dynamo v1.5.0's launch/agg_multimodal.sh documents).

source .env

LLM_PROMPT=${1:-"Describe the image in one sentence."}
IMAGE_URL=${2:-"https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/300px-PNG_transparency_demonstration_1.png"}
API_URL="${SERVICE_URL}/v1/chat/completions"

# Write request body to a variable with no quoting conflicts
read -r -d '' REQUEST_BODY << EOF
{"model":"${MODEL_NAME}","messages":[{"role":"user","content":[{"type":"text","text":"${LLM_PROMPT}"},{"type":"image_url","image_url":{"url":"${IMAGE_URL}"}}]}],"max_tokens":128,"temperature":0.2}
EOF

echo ""
echo "${REQUEST_BODY}"
echo ""

# Base64 encode to completely avoid quoting issues
B64_BODY=$(echo -n "$REQUEST_BODY" | base64 -w0)

CURL_CMD="echo $B64_BODY | base64 -d | curl -s $API_URL -H 'Content-Type: application/json' -d @- | jq ."

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CURL_CMD}\n"; fi

export CMD="kubectl run -it --rm do-curl --image=iankoulski/do-curl --restart=Never -- bash -c \"$CURL_CMD\""

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi

eval "${CMD}"
