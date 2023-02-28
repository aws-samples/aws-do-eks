#!/bin/bash

source .env

echo ""
echo "Showing status of container ${CONTAINER} on ${TO} ..."

case "${TO}" in
	"kubernetes")
		CMD="kubectl -n ${NAMESPACE} get all"
		;;
	*)
		CMD="docker ps -a | grep ${CONTAINER}"
		;;
esac

if [ "${VERBOSE}" == "true" ]; then
	echo ""
        echo "${CMD}"
fi

if [ ! "${DRY_RUN}" == "true" ]; then
        eval "${CMD}"
fi

