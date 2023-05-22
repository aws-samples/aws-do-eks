#!/bin/bash

source ./conf/env.conf

pushd ${IMPL}

CMD="./eks-update.sh"

if [ "${VERBOSE}" == "true" ]; then
        echo ""
        echo "${CMD}"
        echo ""
fi

${CMD}

popd

