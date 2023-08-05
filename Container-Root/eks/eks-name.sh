#!/bin/bash

source ./conf/env.conf

VERBOSE="false"

pushd ${IMPL} > /dev/null

CMD="./eks-name.sh"

if [ "${VERBOSE}" == "true" ]; then
        echo ""
        echo "${CMD}"
        echo ""
fi


if [ "${DRY_RUN}" == "" ]; then
	${CMD}
fi

popd > /dev/null
