#!/bin/bash

source ./conf/env.conf

echo ""
echo "List of EKS clusters ..."

echo ""
CMD="eksctl get cluster $@"
if [ "${VERBOSE}" == "true" ]; then
	echo ""
	echo "${CMD}"
	echo ""
fi
if [ "${DRY_RUN}" == "" ]; then
    ${CMD}
fi

