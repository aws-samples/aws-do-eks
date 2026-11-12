#!/bin/bash

source .env

# RATE_LIMIT_BURST derives from RATE_LIMIT_RPS (nginx wants a literal number in limit_req).
export RATE_LIMIT_BURST=$(( RATE_LIMIT_RPS * 2 ))

# The gateway reads MODEL_KEY from a Secret that only secret-sync.sh creates (from Secrets Manager, through a pipe).
if ! kubectl -n ${NAMESPACE} get secret ${GATEWAY_SECRET_NAME} > /dev/null 2>&1; then
  echo "Secret ${NAMESPACE}/${GATEWAY_SECRET_NAME} not found - run ./secret-sync.sh first (it needs ../modelkey-api deployed)."
  exit 1
fi

# The HTTP-01 challenge for ${ENDPOINT_HOST} is answered through the ingress controller, so the name must resolve to it
# before the Ingress exists, or the certificate Order stays pending until it does (cert-manager retries; nothing breaks).
if ! getent hosts ${ENDPOINT_HOST} > /dev/null 2>&1; then
  echo "WARNING: ${ENDPOINT_HOST} does not resolve yet - create the CNAME first (./dns-cname.sh with HOSTED_ZONE_ID set)."
fi

cat keygate.yaml-template | envsubst > keygate.yaml

export CMD="kubectl apply -f ./keygate.yaml"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "$CMD"

# Verify: everything this folder created carries the part-of label.
kubectl -n ${NAMESPACE} get deploy,svc,ingress,certificate,pods -l app.kubernetes.io/part-of=${GATEWAY_NAME} 2>/dev/null
echo ""
echo "Next: watch 'kubectl -n ${NAMESPACE} get certificate ${GATEWAY_NAME}-tls' until READY=True, then ./test.sh"
