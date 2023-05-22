#!/bin/bash


if [ "${IMPL}" == "impl/eksctl/yaml" ]; then
	echo ""
	echo "Deleting cluster using ${ENV_HOME}${CONF} ..."
	
	CMD="eksctl delete cluster -f ${ENV_HOME}${CONF}"
else
	echo ""
	echo "Unexpected value of IMPL ${IMPL}"
	echo "Please specify IMPL=impl/eksctl/yaml in env.conf"
	echo ""
	exit 1
fi

if [ "${VERBOSE}" == true ]; then
	echo ""
	echo ${CMD}
	echo ""
fi
if [ "${DRY_RUN}" == "" ]; then
    ${CMD}
fi
