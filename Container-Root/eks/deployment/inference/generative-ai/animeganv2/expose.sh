#!/bin/bash

source .env

echo ""
echo "Exposing ${CONTAINER} service on ${TO} ..."

case "${TO}" in
	"kubernetes")
		CMD="kubectl -n ${NAMESPACE} port-forward svc/${APP_NAME} 8080:${PORT_EXTERNAL} &"
		;;
	*)
		CMD="echo 'When TO=docker, the run.sh script also exposes the service'"
		;;
esac

if [ "${VERBOSE}" == "true" ]; then
        echo "${CMD}"
fi

if [ ! "${DRY_RUN}" == "true" ]; then
        eval "${CMD}"
fi
