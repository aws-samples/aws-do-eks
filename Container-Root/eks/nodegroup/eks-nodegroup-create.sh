#!/bin/bash 

echo ""

unset err
if [ "${CLUSTER_NAME}" == "" ]; then
	echo "Environment variable CLUSTER_NAME must be set"
	err="true"
fi

if [ "${nodegroup_name}" == "" ]; then
	echo "Environment variable nodegroup_name must be set"
	err="true"
fi

if [ "${instance_type}" == "" ]; then
	echo "Environment variable instance_type must be set"
	err="true"
fi

if [ "${nodegroup_opts}" == "" ]; then
	nodegroup_opts="--nodes-min 1 --nodes-max 10 --nodes 1 --node-volume-size 60 --node-volume-type gp3 --node-ami-family AmazonLinux2 --node-private-networking --asg-access --external-dns-access --full-ecr-access --alb-ingress-access --appmesh-access --enable-ssm --managed"
fi

if [ "${err}" == "" ]; then
	echo ""
	echo "Creating nodegroup ${nodegroup_name} ..."
	CMD="eksctl create nodegroup --cluster ${CLUSTER_NAME} --name ${nodegroup_name} --node-type $instance_type $nodegroup_opts"
	echo "${CMD}"
	if [ "${DRY_RUN}" == "" ]; then
		${CMD}
	fi
else
	echo "Please correct errors and try again"
fi
