#!/bin/bash

source .env

if [ "${DEBUG}" == "true" ]; then
        set -x
fi

case "${TO}" in
        "compose")
		CMD="${DOCKER_COMPOSE} -f ${COMPOSE_FILE} down"
		;;
	"swarm")
		CMD="docker stack rm ${SWARM_STACK_NAME}"
		;;
	"kubernetes")
		CMD="${KUBECTL} delete -f ${KUBERNETES_APP_PATH}"
		;;
	*)
                checkTO "${TO}"
		CMD="docker container rm -f ${CONTAINER}"
		;;
esac

if [ "${VERBOSE}" == "true" ]; then
        echo "${CMD}"
fi

if [ "${DRY_RUN}" == "false" ]; then
        eval "${CMD}"
fi

if [ "${DEBUG}" == "true" ]; then
        set +x
fi

