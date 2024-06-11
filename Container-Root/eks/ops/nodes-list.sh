#!/bin/bash

CMD="kubectl get nodes -L node.kubernetes.io/instance-type $@"

if [ "${VERBOSE}" == "true" ]; then
	echo ""
	echo "${CMD}"
	echo ""
fi

if [ ! "${DRY_RUN}" == "true" ]; then
	eval "${CMD}"
fi

