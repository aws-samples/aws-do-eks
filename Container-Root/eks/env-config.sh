#!/bin/bash

source ./conf/env.conf

# Edit current environment configuration

CMD="$EDITOR ./conf/env.conf"

if [ "${VERBOSE}" == "true" ]; then
	echo ""
	echo "${CMD}"
	echo ""
fi

if [ "${DRY_RUN}" == "" ]; then
	${CMD}
fi

