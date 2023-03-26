#!/bin/bash

source .env

echo ""
echo "Stopping container ${CONTAINER} on ${TO} ..."

case "${TO}" in
	"kubernetes")
		CMD="kubectl delete -f ${KUBERNETES_APP_PATH}"
		;;
	*)
		CMD="docker container rm -f ${CONTAINER}"
		;;
esac

if [ "${VERBOSE}" == "true" ]; then
        echo "${CMD}"
fi

if [ ! "${DRY_RUN}" == "true" ]; then
        eval "${CMD}"
fi

