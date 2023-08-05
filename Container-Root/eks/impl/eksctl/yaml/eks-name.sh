#!/bin/bash

CMD="eksctl get cluster -f ${ENV_HOME}${CONF} | tail -n 1 | awk '{print \$1}'"
if [ "${VERBOSE}" == "true" ]; then
	echo ""
	echo "${CMD}"
	echo ""
fi
if [ "${DRY_RUN}" == "" ]; then
    eval "${CMD}"
fi
