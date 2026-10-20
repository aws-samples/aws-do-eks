#!/bin/bash

# Run a curl pod and send ONE image prompt to the /v1/chat/completions endpoint.
# This is the single-request vision smoke: a public image URL goes in as image_url
# content (the same request shape dynamo v1.5.0's launch/agg_multimodal.sh documents).

source .env

# -t only when stdin is a terminal: from a script or CI there is no TTY, `kubectl run -it` then fails to
# attach ("Unable to use a TTY" + "couldn't attach to pod") and the response is lost.
_TTY=""; if [ -t 0 ]; then _TTY="t"; fi

LLM_PROMPT=${1:-"Describe the image in one sentence."}
# Default image = an inline data: URL (a 64x64 solid red PNG, generated offline), so the smoke is
# self-contained. The previous default, a Wikimedia thumbnail, is fetched by the WORKER (dynamo's
# image_loader via aiohttp) and Wikimedia answers its default User-Agent with HTTP 403 - measured
# 2026-10-19 on dynamo 1.5.0: `HttpStatusError: HTTP 403 for https://upload.wikimedia.org/...: Forbidden`,
# surfaced to the client as {"message":"Forbidden","code":403}. Pass any https URL as the 2nd argument
# to exercise the remote-fetch path instead.
IMAGE_URL=${2:-"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAS0lEQVR42u3PQQkAAAgAsetfWiP4FgYrsKZeS0BAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEDgsqnc8OJg6Ln3AAAAAElFTkSuQmCC"}
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

export CMD="kubectl run -i${_TTY} --rm do-curl --image=iankoulski/do-curl --restart=Never -- bash -c \"$CURL_CMD\""

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi

eval "${CMD}"
