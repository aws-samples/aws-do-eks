#!/bin/bash

# Three checks against the public endpoint: no key -> 403, the current key -> 200 with the model list, a streamed
# completion prints chunks. The key is read from the Kubernetes Secret into a shell variable and never printed.

source .env

BASE="https://${ENDPOINT_HOST}/v1"
FAIL=0

code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "${BASE}/models")
if [ "${code}" == "403" ]; then echo "PASS  no key -> 403"; else echo "FAIL  no key -> ${code} (expected 403)"; FAIL=1; fi

KEY=$(kubectl -n ${NAMESPACE} get secret ${GATEWAY_SECRET_NAME} -o jsonpath='{.data.MODEL_KEY}' | base64 -d)
if [ "${KEY}" == "" ]; then echo "FAIL  Secret ${NAMESPACE}/${GATEWAY_SECRET_NAME} has no MODEL_KEY"; exit 1; fi

models=$(curl -s --max-time 20 -H "Authorization: Bearer ${KEY}" "${BASE}/models")
model=$(echo "${models}" | python3 -c 'import json, sys; print(json.load(sys.stdin)["data"][0]["id"])' 2>/dev/null)
if [ "${model}" != "" ]; then echo "PASS  with key -> 200, model ${model}"; else echo "FAIL  with key -> ${models:0:200}"; FAIL=1; fi

if [ "${model}" != "" ]; then
  body="{\"model\":\"${model}\",\"messages\":[{\"role\":\"user\",\"content\":\"Say hello in five words.\"}],\"max_tokens\":32,\"stream\":true}"
  chunks=$(curl -sN --max-time 120 -H "Authorization: Bearer ${KEY}" -H "Content-Type: application/json" -d "${body}" "${BASE}/chat/completions" | grep -c '^data: ')
  if [ "${chunks}" -gt 1 ]; then echo "PASS  streamed completion -> ${chunks} chunks"; else echo "FAIL  streamed completion -> ${chunks} chunks"; FAIL=1; fi
fi

exit ${FAIL}
