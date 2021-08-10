#!/bin/bash

echo ""

unset err

if [ "${nodegroup_name}" == "" ]; then
	echo "Environment variable nodegroup_name must be set"
	err=true
fi

if [ "${nodegroup_size}" == "" ]; then
	echo "Environment variable nodegroup_size must be set"
	err=true
fi

if [ "${CLUSTER_NAME}" == "" ]; then
	echo "Environment variable CLUSTER_NAME must be set"
	err=true
fi

if [ "${CLUSTER_REGION}" == "" ]; then
	echo "Environment variable CLUSTER_REGION must be set"
	err=true
fi 

if [ "${err}" == "" ]; then
	echo ""
	echo "Scaling node group ${nodegroup_name} in cluster ${CLUSTER_NAME} to ${nodegroup_size} ..."
	ng=$(eksctl get nodegroup --cluster ${CLUSTER_NAME} --name ${nodegroup_name} --output json)
	#echo $ng
	ng=$(echo $ng | cut -d { -f 2 | cut -d } -f 1)
	#echo $ng
	ng="[ {${ng}} ]"
	#echo $ng
	asg=$(echo ${ng} | jq -r '.[].AutoScalingGroupName')
	if [ "${asg}" == "" ]; then
		# if asg was not determined from eksctl, try finding it from aws cli
		ng=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name ${nodegroup_name}) 
		asg=$(echo $ng | jq -r '.nodegroup.resources.autoScalingGroups[0].name')
		max=$(echo ${ng} | jq -r '.nodegroup.scalingConfig.maxSize')
	else
		max=$(echo ${ng} | jq '.[].MaxSize')
	fi
	echo "asg=$asg"
	min=0
	if [ $max -lt $nodegroup_size ]; then
		max=$((nodegroup_size+10))
	fi
	echo "max=$max"
	CMD="aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${asg} --min-size 0 --max-size ${max} --desired-capacity ${nodegroup_size} --region ${CLUSTER_REGION}"
	echo ${CMD}
	if [ "${DRY_RUN}" == "" ]; then
		${CMD}
	fi
else
	echo "Please correct any reported errors and try again"
fi

