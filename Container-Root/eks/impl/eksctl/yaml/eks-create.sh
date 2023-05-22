#!/bin/bash

if [ "$IMPL" == "impl/eksctl/yaml" ]; then

	# Create EKS Cluster with initial nodegroup to run kube-system pods
	echo ""
	date
	echo "Creating cluster using ${ENV_HOME}${CONF} ..."
	CMD="eksctl create cluster -f ${ENV_HOME}${CONF}"
	if [ "${VERBOSE}" == "true" ]; then
		echo ""
		echo "${CMD}"
		echo ""
	fi
	if [ "${DRY_RUN}" == "" ]; then
		${CMD}
	fi

	# Done creating EKS Cluster
	echo ""
	date
	echo "Done creating cluster using ${ENV_HOME}${CONF}"
	echo ""
else
	echo ""
	echo "Uncexpected value of IMPL setting $IMPL. Please specify IMPL=impl/eksctl/yaml in env.conf"
	echo ""
fi
