#!/bin/bash

pushd $(dirname ${ENV_HOME}${CONF})

echo ""
echo "Status of cluster using terraform template with variables ${CONF} ..."

echo ""
CMD="terraform show"
if [ "${VERBOSE}" == "true" ]; then
	echo ""
	echo "${CMD}"
	echo ""
fi
if [ "${DRY_RUN}" == "" ]; then
    ${CMD}
fi

popd
