#!/bin/bash

# Deploys (creates or updates) the modelkey-api stack. Idempotent; prints the stack outputs (ApiId, InvokeUrl,
# InvokeArn, SecretArn). Needs CloudFormation, IAM, Lambda, API Gateway and Secrets Manager rights in the account.

source .env

OVERRIDES="SecretName=${SECRET_NAME} EndpointUrl=${ENDPOINT_URL} ModelId=${MODEL_ID} StageName=${STAGE_NAME}"
if [ "${PRINCIPAL_ORG_ID}" != "" ]; then OVERRIDES="${OVERRIDES} PrincipalOrgId=${PRINCIPAL_ORG_ID}"; fi
if [ "${SOURCE_VPCE_IDS}" != "" ]; then OVERRIDES="${OVERRIDES} SourceVpceIds=${SOURCE_VPCE_IDS}"; fi

export CMD="aws cloudformation deploy --region ${API_REGION} --stack-name ${STACK_NAME} --template-file template.yaml --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset --parameter-overrides ${OVERRIDES}"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "$CMD" || exit 1

aws cloudformation describe-stacks --region ${API_REGION} --stack-name ${STACK_NAME} --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' --output table
echo ""
echo "Next: ../gateway/secret-sync.sh (copies the generated key into the cluster Secret the gateway reads)."
