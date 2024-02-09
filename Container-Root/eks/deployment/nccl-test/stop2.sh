#!/bin/bash

. ./env

TEST_NAME=$1
if [ "$1" == "" ]; then
	TEST_NAME="all-reduce-pair"
fi

echo ""
echo "Stopping MPI jobs for test $TEST_NAME  ..."
echo ""

CMD="kubectl delete -f ./${TEST_NAME}"

if [ "$VERBOSE" == "true" ]; then
	echo ""
	echo "$CMD"
	echo ""
fi

if [ ! "$DRY_RUN" == "true" ]; then
	eval "$CMD"
fi

rm -rf ./$TEST_NAME

