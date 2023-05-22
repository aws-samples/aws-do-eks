#!/bin/bash

source ${ENV_HOME}${CONF}

if [ "${IMPL}" == "impl/eksctl/env" ]; then

	echo ""
	echo "Deleting cluster ${CLUSTER_NAME} ..."

	CMD="eksctl delete cluster --name ${CLUSTER_NAME}"
else
	echo ""
	echo "Unexpected IMPL setting $IMPL"
	echo "Please specify IMPL=impl/eksctl/env in env.conf"
	echo ""
	exit 1
fi

if [ "$VERBOSE" == "true" ]; then
	echo ""
	echo ${CMD}
	echo ""
fi
if [ "${DRY_RUN}" == "" ]; then
    ${CMD}
fi
