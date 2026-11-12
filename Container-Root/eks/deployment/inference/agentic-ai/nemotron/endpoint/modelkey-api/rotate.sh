#!/bin/bash

# Rotates the model key: Secrets Manager generates the new value, the JSON document is rebuilt in a pipe and stored
# with put-secret-value - the key is never on a command line, in a file or on the terminal. Then run
# ../gateway/secret-sync.sh: the gateway restarts on the new key and every copy of the old one stops working.
# Callers of POST /modelkey receive the new key from that moment on.

source .env

aws secretsmanager get-random-password --region ${API_REGION} --password-length 48 --exclude-punctuation --exclude-uppercase --query RandomPassword --output text \
  | python3 -c 'import json, os, sys; print(json.dumps({"endpoint": os.environ["ENDPOINT_URL"], "model": os.environ["MODEL_ID"], "api_key": sys.stdin.read().strip()}))' \
  | aws secretsmanager put-secret-value --region ${API_REGION} --secret-id ${SECRET_NAME} --secret-string file:///dev/stdin --query VersionId --output text

echo "Rotated ${SECRET_NAME} in ${API_REGION}. Now run: (cd ../gateway && ./secret-sync.sh)"
