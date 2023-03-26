#!/bin/bash

source .env

echo ""
echo "Hiding ${CONTAINER} service on ${TO} ..."

case "${TO}" in
	"kubernetes")
		CMD="kill -9 $(ps -aef | grep port-forward | grep ${APP_NAME} | head -n 1 | awk '{print $2}')"
		;;
	*)
		CMD="echo 'When TO=docker, the stop.sh script also hides the service'"
		;;
esac

if [ "${VERBOSE}" == "true" ]; then
        echo "${CMD}"
fi

if [ ! "${DRY_RUN}" == "true" ]; then
        eval "${CMD}"
fi

