#!/bin/bash

source fsx.conf

if [ ! "$FSX_SUBNET_ID" == "" ]; then
	FSX_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${FSX_SECURITY_GROUP_NAME}" --query "SecurityGroups.GroupId" --output text)
	if [ ! "$FSX_SECURITY_GROUP_ID" == "" ]; then
		echo ""
		echo "Creating FSxL volume with capacity $FSX_STORAGE_CAPACITY and EFA enabled ..."

		CMD="aws fsx create-file-system --storage-capacity $STORAGE_CAPACITY --storage-type SSD --file-system-type LUSTRE --subnet-ids $SUBNET_ID --security-group-ids $SECURITY_GROUP_ID --lustre-configuration 'DeploymentType=PERSISTENT_2,PerUnitStorageThroughput=${FSX_THROUGHPUT},EfaEnabled=true,MetadataConfiguration={Mode=AUTOMATIC}'"
		if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
		FILE_SYSTEM_RESPONSE=$(eval "${CMD}")
		echo "$FILE_SYSTEM_RESPONSE"
		export FILE_SYSTEM_ID=$(echo $FILE_SYSTEM_RESPONSE | jq -r .FileSystem.FileSystemId)
		echo ""
		echo "FILE_SYSTEM_ID=$FILE_SYSTEM_ID"
	else
		echo "SECURITY_GROUP_ID is required"
	fi
else
	echo "SUBNET_ID is required"
fi


