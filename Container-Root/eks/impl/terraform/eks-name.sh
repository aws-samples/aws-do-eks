#!/bin/bash

# Extract the cluster_name default value from variables.tf
# The CONF variable points to the variables.tf file for the active terraform configuration

VARS_FILE="${ENV_HOME}${CONF}"

if [ -f "${VARS_FILE}" ]; then
    # Parse the default value of the cluster_name variable from variables.tf
    CLUSTER_NAME=$(awk '/variable "cluster_name"/,/^}/' "${VARS_FILE}" | grep 'default' | sed 's/.*default.*=.*"\(.*\)".*/\1/')
    echo "${CLUSTER_NAME}"
else
    echo "Error: ${VARS_FILE} not found" >&2
    exit 1
fi
