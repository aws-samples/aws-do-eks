#!/bin/bash

pushd $(dirname ${ENV_HOME}${CONF})

if [ "$IMPL" == "impl/terraform" ]; then

	# Create EKS Cluster with initial nodegroup to run kube-system pods
	echo ""
	date
	echo "Creating cluster using terraform template with variables ${CONF} ..."
	CMD="terraform init && terraform plan -out tfplan && terraform apply -auto-approve tfplan"
	if [ "${VERBOSE}" == "true" ]; then
		echo ""
		echo "${CMD}"
		echo ""
	fi
	if [ "${DRY_RUN}" == "" ]; then
		eval "${CMD}"
	fi

	# Done creating EKS Cluster
	echo ""
	date
	echo "Done creating cluster using terraform template with variables ${CONF}"
	echo ""
else
	echo ""
	echo "Uncexpected value of IMPL setting $IMPL. Please specify IMPL=impl/terraform in env.conf"
	echo ""
fi

popd
