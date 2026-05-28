#!/bin/bash

usage () {
	echo ""
	echo "$0 - Delete FSxL file system by ID"
	echo "Usage: $0 <file_system_id>"
	echo ""	
}

FILE_SYSTEM_ID=$1

if [ "$1" == "" ]; then
	usage
else
	echo ""
	echo "Deleting FSxL file system $1 ..."

	CMD="aws fsx delete-file-system --file-system-id $FILE_SYSTEM_ID"
	if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
	eval "${CMD}"
fi

