#!/bin/bash

pushd $(dirname ${ENV_HOME}${CONF})

if [ "${IMPL}" == "impl/terraform" ]; then
	echo ""
	echo "Deleting cluster using terraform template with variables ${CONF} ..."
	
	CMD="terraform destroy -auto-approve"
else
	echo ""
	echo "Unexpected value of IMPL ${IMPL}"
	echo "Please specify IMPL=impl/terraform in env.conf"
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

popd
