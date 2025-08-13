#!/bin/bash

source .env

if [ "${DEBUG}" == "true" ]; then
        set -x
fi

case "${TO}" in
        "compose")
		if [ "$1" == "" ]; then
			CMD="${DOCKER_COMPOSE} -f ${COMPOSE_FILE} logs -f"
		else
			CMD="docker logs -f ${COMPOSE_PROJECT_NAME}_${CONTAINER}_$1"
		fi
		;;
	"swarm")
		if [ "$1" == "" ]; then
			CMD="docker service logs -f ${SWARM_STACK_NAME}_${SWARM_SERVICE_NAME}"
		else
			CMD="docker service ps ${SWARM_STACK_NAME}_${SWARM_SERVICE_NAME} | grep ${SWARM_SERVICE_NAME}.$1 | cut -d ' ' -f 1 | xargs docker service logs -f"
		fi	
		;;
	"kubernetes")
		CMD="${KUBETAIL} ${APP_NAME} -n ${NAMESPACE}"
		;;
	*)
                checkTO "${TO}"
		CMD="docker container logs -f ${CONTAINER}"
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
