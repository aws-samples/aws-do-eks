#!/bin/bash

# Creates (UPSERT) the CNAME ${ENDPOINT_HOST} -> <hostname of the ingress controller's load balancer> in the Route 53
# zone HOSTED_ZONE_ID. Run it before run.sh: the ACME HTTP-01 challenge is answered through that name. Needs Route 53
# rights in the account that owns the zone; the cluster side is a read of one Service.

source .env

if [ "${HOSTED_ZONE_ID}" == "" ]; then
  echo "Set HOSTED_ZONE_ID (the Route 53 hosted zone that holds ${ENDPOINT_HOST}) in .env or on the command line."
  exit 1
fi

LB_HOSTNAME=$(kubectl -n ${INGRESS_CONTROLLER_NAMESPACE} get svc ${INGRESS_CONTROLLER_SERVICE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
if [ "${LB_HOSTNAME}" == "" ]; then
  echo "Service ${INGRESS_CONTROLLER_NAMESPACE}/${INGRESS_CONTROLLER_SERVICE} has no load balancer hostname yet."
  exit 1
fi

echo "UPSERT CNAME ${ENDPOINT_HOST} -> ${LB_HOSTNAME} (zone ${HOSTED_ZONE_ID})"
ENDPOINT_HOST=${ENDPOINT_HOST} LB_HOSTNAME=${LB_HOSTNAME} python3 -c '
import json, os
print(json.dumps({"Comment": "nemotron endpoint key gateway", "Changes": [{"Action": "UPSERT", "ResourceRecordSet": {
  "Name": os.environ["ENDPOINT_HOST"], "Type": "CNAME", "TTL": 300,
  "ResourceRecords": [{"Value": os.environ["LB_HOSTNAME"]}]}}]}))' \
  | aws route53 change-resource-record-sets --hosted-zone-id ${HOSTED_ZONE_ID} --change-batch file:///dev/stdin --query ChangeInfo.Status --output text

echo "Check: dig +short ${ENDPOINT_HOST}"
