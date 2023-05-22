#!/bin/bash

source ${ENV_HOME}${CONF}

if [ "$IMPL" == "impl/eksctl/env" ]; then

	# Create EKS Cluster with initial nodegroup to run kube-system pods
	echo ""
	date
	echo "Creating cluster ${CLUSTER_NAME} ..."
	CMD="eksctl create cluster --name ${CLUSTER_NAME} --region ${CLUSTER_REGION} --version ${CLUSTER_K8S_VERSION} \
	--zones "${CLUSTER_ZONES}" --vpc-cidr ${CLUSTER_VPC_CIDR} ${CLUSTER_OPTIONS}"
	echo "${CMD}"
	if [ "${DRY_RUN}" == "" ]; then
		${CMD}
	fi

	# Create CPU nodegroups
	echo ""
	echo "Creating CPU nodegroups in cluster ${CLUSTER_NAME} ..."
	export nodegroup_opts="${CPU_NODEGROUP_OPTIONS}"
	for index in ${!CPU_NODEGROUP_INSTANCE_TYPES[@]}
	do
		export instance_type=${CPU_NODEGROUP_INSTANCE_TYPES[$index]}
		export nodegroup_name=$(echo $instance_type | sed -e 's/\./-/g')
		nodegroup/eks-nodegroup-create.sh
	done

	# Create GPU nodegroups
	echo ""
	echo "Creating GPU nodegroups in cluster ${CLUSTER_NAME} ..."
	export nodegroup_opts="${GPU_NODEGROUP_OPTIONS}"
	for index in ${!GPU_NODEGROUP_INSTANCE_TYPES[@]}
	do
		export instance_type=${GPU_NODEGROUP_INSTANCE_TYPES[$index]}
		export nodegroup_name=$(echo $instance_type | sed -e 's/\./-/g')
		nodegroup/eks-nodegroup-create.sh
	done

	# Create ASIC nodegroups
	echo ""
	echo "Creating ASIC nodegroups in cluster ${CLUSTER_NAME} ..."
	export nodegroup_opts="${ASIC_NODEGROUP_OPTIONS}"
	for index in ${!ASIC_NODEGROUP_INSTANCE_TYPES[@]}
	do
		export instance_type=${ASIC_NODEGROUP_INSTANCE_TYPES[$index]}
		export nodegroup_name=$(echo $instance_type | sed -e 's/\./-/g')
		nodegroup/eks-nodegroup-create.sh
	done

	# Create Fargate Profiles
	echo ""
	echo "Creating Fargate Profiles in cluster ${CLUSTER_NAME} ..."
	for index in ${!SERVERLESS_FARGATE_PROFILE_NAMES}
	do
		export fargateprofile_name=${SERVERLESS_FARGATE_PROFILE_NAMES[$index]}
		fargateprofile/eks-fargateprofile-create.sh
	done

	# Scale cluster as specified
	./eks-update.sh

	# Optionally deploy cluster autoscaler
	if [ "$CLUSTER_AUTOSCALER_DEPLOY" == "true" ]; then
		pushd ${ENV_HOME}deployment/cluster-autoscaler
		./deploy-cluster-autoscaler.sh
		popd
	fi

	# Done creating EKS Cluster
	echo ""
	date
	echo "Done creating cluster ${CLUSTER_NAME}"
	echo ""
else
	echo ""
	echo "Uncexpected value of IMPL setting $IMPL. Please specify IMPL=impl/eksctl/env in env.conf"
	echo ""
fi
