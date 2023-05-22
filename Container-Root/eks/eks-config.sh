#!/bin/bash

source ./conf/env.conf

# Edit current cluster configuration

CMD="$EDITOR ${ENV_HOME}${CONF}"

if [ "${VERBOSE}" == "true" ]; then
	echo ""
	echo "${CMD}"
	echo ""
fi

if [ "${DRY_RUN}" == "" ]; then
	${CMD}
fi

