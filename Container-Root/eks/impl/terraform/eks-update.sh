#!/bin/bash

pushd $(dirname ${ENV_HOME}${CONF})

echo ""
date
echo "Updating cluster using terraform template with variables ${CONF} ..."

CMD="terraform plan -out tfplan && terraform apply -auto-approve tfplan"

if [ "${VERBOSE}" == "true" ]; then
	echo ""
	echo "${CMD}"
	echo ""
fi

if [ "${DRY_RUN}" == "" ]; then
	eval "${CMD}"
fi

echo ""
date
echo "Done updating cluster using terraform templaste with variables ${CONF}"
echo ""

popd
