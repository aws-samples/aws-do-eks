#!/bin/bash

# Deletes the modelkey-api stack: the API, the Lambda and its role, and the secret (Secrets Manager schedules the
# secret for deletion with a recovery window; a later deploy.sh with the same SECRET_NAME inside that window fails
# until `aws secretsmanager delete-secret --secret-id ${SECRET_NAME} --force-delete-without-recovery` or a new name).
# The key gateway keeps working with the key it already holds; ../gateway/stop.sh revokes it.

source .env

export CMD="aws cloudformation delete-stack --region ${API_REGION} --stack-name ${STACK_NAME}"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "$CMD" || exit 1

echo "Waiting for the delete to complete ..."
aws cloudformation wait stack-delete-complete --region ${API_REGION} --stack-name ${STACK_NAME} && echo "Done."
