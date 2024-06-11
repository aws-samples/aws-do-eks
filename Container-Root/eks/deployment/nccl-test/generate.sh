#!/bin/bash

export TEST_NAME=$1
if [ "$1" == "" ]; then
	export TEST_NAME=all-reduce
fi
echo ""
echo "Generating manifest: ${TEST_NAME}.yaml"
echo ""

CMD="source .env; cat ./${TEST_NAME}.yaml-template | envsubst > ${TEST_NAME}.yaml"

if [ "${VERBOSE}" == "true" ]; then
	echo ""
	echo "$CMD"
	echo ""
fi

if [ ! "${DRY_RUN}" == "true" ]; then
	eval "$CMD"
fi

echo "Done."
echo ""
