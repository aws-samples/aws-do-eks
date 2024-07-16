#!/bin/bash

TEST_NAME=$1
if [ "$1" == "" ]; then
	TEST_NAME="all-reduce"
fi

./generate.sh ${TEST_NAME}

CMD="kubectl apply -f ./${TEST_NAME}.yaml"

if [ "$VERBOSE" == "true" ]; then
	echo ""
	echo "$CMD"
	echo ""
fi

if [ ! "$DRY_RUN" == "true" ]; then
	eval "$CMD"
fi

