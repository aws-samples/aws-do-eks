#!/bin/bash

# Creates or refreshes the Kubernetes Secret the key gateway reads MODEL_KEY from, straight from the Secrets Manager
# secret that ../modelkey-api owns. The value travels through a pipe only: it is never written to a file, never put on
# a command line (no shell history, no process list) and never printed. Run it once after ../modelkey-api/deploy.sh
# and again after every ../modelkey-api/rotate.sh - the rollout restart below makes the gateway accept the new key
# and refuse the old one.

source .env

aws secretsmanager get-secret-value --region ${SECRET_REGION} --secret-id ${SECRET_NAME} --query SecretString --output text \
  | python3 -c 'import json, sys; sys.stdout.write(json.load(sys.stdin)["api_key"])' \
  | kubectl -n ${NAMESPACE} create secret generic ${GATEWAY_SECRET_NAME} --from-file=MODEL_KEY=/dev/stdin --dry-run=client -o yaml \
  | kubectl label --local -f - app.kubernetes.io/part-of=${GATEWAY_NAME} -o yaml \
  | kubectl apply -f -

# No-op before the first run.sh; after it, the pods restart and read the current key.
kubectl -n ${NAMESPACE} rollout restart deployment/${GATEWAY_NAME} 2>/dev/null || true
kubectl -n ${NAMESPACE} get secret ${GATEWAY_SECRET_NAME} -o jsonpath='{.metadata.name}{" created "}{.metadata.creationTimestamp}{"\n"}'
