#!/bin/bash

source .env

echo ""
echo "Showing logs from container ${CONTAINER} on ${TO} ..."

case "${TO}" in
	"kubernetes")
		CMD="kubetail ${APP_NAME} -n ${NAMESPACE} -s 30m"
		;;
	*)
		CMD="docker container logs -f ${CONTAINER}"
		;;
esac

if [ "${VERBOSE}" == "true" ]; then
        echo "${CMD}"
fi

if [ ! "${DRY_RUN}" == "true" ]; then
        eval "${CMD}"
fi

