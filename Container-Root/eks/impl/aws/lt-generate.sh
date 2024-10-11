#!/bin/bash

source ./nodegroup.conf
export USERDATA=$(./userdata.sh | base64 -w 0)

SG=$(aws eks describe-cluster --region $REGION --name $CLUSTER | jq -r '.cluster.resourcesVpcConfig.clusterSecurityGroupId')
#aws ec2 authorize-security-group-egress --group-id $SG --protocol -1 --port all --source-group $S

export TEMPLATE_FILE=nodegroup-odcr.yaml-template
if [ "$MARKET_TYPE" == "capacity-block" ]; then
	export TEMPLATE_FILE=nodegroup-cb.yaml-template
fi	

cat ./${TEMPLATE_FILE} | envsubst 

