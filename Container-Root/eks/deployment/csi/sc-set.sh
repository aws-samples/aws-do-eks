#!/bin/bash

# Sets default storage class
# Reference: https://kubernetes.io/docs/tasks/administer-cluster/change-default-storage-class/

help() {
	echo ""
	echo "Usage: $0 <storage_class_name>"
	echo ""
	echo "storage_class_name   - name of the storage class to set as default"
	echo ""
}

SC=$1

if [ "$SC" == "" ]; then
	help
else
	CMD="kubectl patch storageclass ${SC} -p '{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}'"
	if [ ! "$verbose" == "false" ]; then echo -e "\n${CMD}\n"; fi
	eval "$CMD"
fi

