#!/bin/bash

source ./conf/env.conf

pushd $IMPL

CMD="./eks-create.sh"

if [ "${VERBOSE}" == "true" ]; then
	echo ""
	echo "${CMD}"
	echo ""
fi

${CMD}

popd
