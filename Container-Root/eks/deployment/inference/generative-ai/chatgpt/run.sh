#!/bin/bash

source .env

if [ -z "$1" ]; then
	MODE=-d
else
	MODE=-it
fi 

function generate_kubernetes_manifests
{
	echo "Generating Kubernetes manifests ..."
	if [ ! -d "${KUBERNETES_APP_PATH}" ]; then
		mkdir -p "${KUBERNETES_APP_PATH}"
	fi
	CMD="BASE_PATH=$(pwd); cd ${KUBERNETES_TEMPLATE_PATH}; for f in *.yaml; do cat \$f | envsubst > \${BASE_PATH}/\${KUBERNETES_APP_PATH}/\$f; done; cd \${BASE_PATH}"
        if [ "${VERBOSE}" == "true" ]; then
                echo "${CMD}"
        fi
        if [ ! "${DRY_RUN}" == "true" ]; then
                eval "${CMD}"
        fi 
	
}

echo ""
echo "Running container ${CONTAINER} on ${TO} ..."

case "${TO}" in
	"kubernetes")
		generate_kubernetes_manifests
		CMD="kubectl -n ${NAMESPACE} apply -f ${KUBERNETES_APP_PATH}"
		;;
	*)
		CMD="docker container run ${RUN_OPTS} ${CONTAINER_NAME} ${MODE} ${NETWORK} ${PORT_MAP} ${VOL_MAP} ${REGISTRY}${IMAGE}${TAG} $@"
		;;
esac

if [ "${VERBOSE}" == "true" ]; then
	echo "${CMD}"
fi

if [ ! "${DRY_RUN}" == "true" ]; then
	eval "${CMD}"
fi

