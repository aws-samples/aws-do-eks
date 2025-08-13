#!/bin/bash

source .env

if [ "${DEBUG}" == "true" ]; then
	set -x
fi

if [ -z "$1" ]; then
	MODE=-d
else
	MODE=-it
fi 

function generate_docker_compose
{
	CMD="${ENVSUBST} < ${COMPOSE_TEMPLATE} > ${COMPOSE_FILE}" 
	if [ "${VERBOSE}" == "true" ]; then
		echo "${CMD}"
	fi
	if [ "${DRY_RUN}" == "false" ]; then
		eval "${CMD}"
	fi
}

function generate_kubernetes_manifests
{
	CMD="BASE_PATH=$(pwd); cd ${KUBERNETES_TEMPLATE_PATH}; for f in *.yaml; do cat \$f | envsubst > \${BASE_PATH}/\${KUBERNETES_APP_PATH}/\$f; done; cd \${BASE_PATH}"
        if [ "${VERBOSE}" == "true" ]; then
                echo "${CMD}"
        fi
        if [ "${DRY_RUN}" == "false" ]; then
                eval "${CMD}"
        fi 
	
}

case "${TO}" in
	"compose")
		generate_docker_compose
		CMD="${DOCKER_COMPOSE} -f ${COMPOSE_FILE} up -d"
		;;
	"swarm")
		generate_docker_compose
		CMD="docker stack deploy -c ${COMPOSE_FILE} ${SWARM_STACK_NAME}"
		;;
	"kubernetes")
		generate_kubernetes_manifests
		CMD="${KUBECTL} -n ${NAMESPACE} apply -f ${KUBERNETES_APP_PATH}"
		;;
	*)
		checkTO "${TO}"
		CMD="docker container run ${RUN_OPTS} ${CONTAINER_NAME} ${MODE} ${NETWORK} ${PORT_MAP} ${VOL_MAP} ${REGISTRY}${IMAGE}${TAG} $@"
		;;
esac

if [ "${VERBOSE}" == "true" ]; then
	echo "${CMD}"
fi

if [ "${DRY_RUN}" == "false" ]; then
	eval "${CMD}"
	echo ""
fi

if [ "${DEBUG}" == "true" ]; then
	set +x
fi
