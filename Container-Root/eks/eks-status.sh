#!/bin/bash

source ./conf/env.conf

pushd ${IMPL}

CMD="./eks-status.sh"

if [ "${VERBOSE}" == "true" ]; then
        echo ""
        echo "${CMD}"
        echo ""
fi


if [ "${DRY_RUN}" == "" ]; then
	${CMD}
fi

popd
