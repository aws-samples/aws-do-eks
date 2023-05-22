#!/bin/bash

echo ""
date
echo "Updating cluster using manifest ${ENV_HOME}${CONF} ..."

CMD="eksctl upgrade cluster -f ${ENV_HOME}${CONF}"

if [ "${VERBOSE}" == "true" ]; then
	echo ""
	echo "${CMD}"
	echo ""
fi

if [ "${DRY_RUN}" == "" ]; then
	${CMD}
fi

echo ""
date
echo "Done updating cluster using manifest ${ENV_HOME}${CONF}"
echo ""

