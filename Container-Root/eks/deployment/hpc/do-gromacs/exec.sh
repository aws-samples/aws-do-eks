#!/bin/bash

source .env

if [ "$1" == "" ]; then
	CMD="/bin/bash"
else
	CMD=$@
fi

if [ "$TO" == "docker" ]; then

	docker container exec -it ${CONTAINER} $CMD 

elif [ "$TO" == "kubernetes" ]; then

	kubectl -n ${K8S_NAMESPACE} exec -it $(kubectl -n ${K8S_NAMESPACE} get pods | grep do-gromacs | head -n 1 | tail -n 1 | cut -d ' ' -f 1) -- $CMD
else
	echo ""
	echo "Unknwn Target Orchestrator $TO"
fi
echo ""

