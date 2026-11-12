#!/bin/bash

# Calls POST /modelkey on the private API with SigV4 (awscurl) from inside a VPC that has an execute-api interface
# endpoint, prints endpoint and model, and with --ssm stores the three values as SSM parameters for the attendees.
# The key itself is never printed.
#
#   MODELKEY_URL=https://<api-id>.execute-api.us-west-2.amazonaws.com/dev/modelkey ./get-modelkey.sh [--ssm]
#
# Exit 0 = key stored/available; 3 = the API answered 404 unavailable (skip, do not fail a provisioning step);
# 1 = any other failure (403 = missing execute-api:Invoke or no VPC endpoint path).

set -euo pipefail

URL="${MODELKEY_URL:?set MODELKEY_URL to the InvokeUrl output of the modelkey-api stack}"
REGION="${MODELKEY_REGION:-$(echo "${URL}" | sed -E 's#https://[^.]+\.execute-api\.([a-z0-9-]+)\..*#\1#')}"
PREFIX="${SSM_PREFIX:-/workshop/nemotron}"

if ! command -v awscurl > /dev/null 2>&1; then
  echo "awscurl not found: pip install awscurl (or sign with curl --aws-sigv4, see README.md)"
  exit 1
fi

RESPONSE=$(awscurl --service execute-api --region "${REGION}" -X POST "${URL}" 2>&1) || {
  echo "POST /modelkey failed: ${RESPONSE:0:300}"
  exit 1
}

STATUS=$(echo "${RESPONSE}" | python3 -c 'import json, sys; d = json.load(sys.stdin); print(d.get("status", "ok" if d.get("api_key") else "error"))')
if [ "${STATUS}" == "unavailable" ]; then
  echo "modelkey unavailable (404): the key is not being handed out right now - skipping"
  exit 3
elif [ "${STATUS}" != "ok" ]; then
  echo "unexpected answer: ${RESPONSE:0:300}"
  exit 1
fi

ENDPOINT=$(echo "${RESPONSE}" | python3 -c 'import json, sys; print(json.load(sys.stdin)["endpoint"])')
MODEL=$(echo "${RESPONSE}" | python3 -c 'import json, sys; print(json.load(sys.stdin)["model"])')
echo "endpoint ${ENDPOINT}"
echo "model    ${MODEL}"

if [ "${1:-}" == "--ssm" ]; then
  aws ssm put-parameter --name "${PREFIX}/endpoint" --type String --overwrite --value "${ENDPOINT}" > /dev/null
  aws ssm put-parameter --name "${PREFIX}/model" --type String --overwrite --value "${MODEL}" > /dev/null
  # the key goes through stdin into a file:// URI, never onto the command line
  echo "${RESPONSE}" | python3 -c 'import json, sys; sys.stdout.write(json.load(sys.stdin)["api_key"])' \
    | aws ssm put-parameter --name "${PREFIX}/api_key" --type SecureString --overwrite --value file:///dev/stdin > /dev/null
  echo "stored ${PREFIX}/endpoint, ${PREFIX}/model, ${PREFIX}/api_key (SecureString)"
fi
