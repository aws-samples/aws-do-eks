#!/bin/bash

source .env

if [ "$TO" == "docker" ]; then

	export MODE=-it

	echo "Testing ${IMAGE} ..."

	docker container run ${RUN_OPTS} ${CONTAINER_NAME}-test ${MODE} --rm ${NETWORK} ${PORT_MAP} ${VOL_MAP} ${REGISTRY}${IMAGE}${TAG} sh -c "for t in \$(ls /test*.sh); do echo Running test \$t; \$t; done;" 

elif [ "$TO" == "kubernetes" ]; then
	unset DEBUG; kubectl -n ${K8S_NAMESPACE} exec -it $( kubectl -n ${K8S_NAMESPACE} get pod | grep gromacs | head -n 1 | tail -n 1 | cut -d ' ' -f 1 ) -- /bin/bash -c "for t in \$(ls /test*.sh); do echo Running test \$t; \$t; done"

else
	echo ""
	echo "Unknown Target Orchestrator $TO"
fi
echo ""

