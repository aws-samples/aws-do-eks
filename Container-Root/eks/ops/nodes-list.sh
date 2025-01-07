#!/bin/bash

CMD="kubectl get nodes -L node.kubernetes.io/instance-type -L sagemaker.amazonaws.com/node-health-status $@"

if [ ! "${VERBOSE}" == "false" ]; then
	echo ""
	echo "${CMD}"
	echo ""
fi

if [ ! "${DRY_RUN}" == "true" ]; then
	eval "${CMD}"
fi

