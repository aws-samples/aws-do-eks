#!/bin/bash

source .env

if [ "${DEBUG}" == "true" ]; then
        set -x
fi

case "${TO}" in
	"compose")
		CMD="${DOCKER_COMPOSE} -f ${COMPOSE_FILE} ps -a"
		;;
	"swarm")
		CMD="docker stack ps ${SWARM_STACK_NAME}"
		;;
	"kubernetes")
		CMD="${KUBECTL} -n ${NAMESPACE} get all"
		;;
	*)
		checkTO "${TO}"
		CMD="docker ps -a | grep ${CONTAINER}"
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

