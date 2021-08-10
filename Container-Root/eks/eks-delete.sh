#!/bin/bash

source ./eks.conf

echo ""
echo "Deleting cluster ${CLUSTER_NAME} ..."

CMD="eksctl delete cluster --name ${CLUSTER_NAME}"

echo ${CMD}
if [ "${DRY_RUN}" == "" ]; then
    ${CMD}
fi
