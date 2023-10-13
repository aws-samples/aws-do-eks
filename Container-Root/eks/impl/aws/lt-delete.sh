#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

function usage(){
	echo ""
	echo "Usage: $0 <template_id>"
	echo ""
}

if [ "$1" == "" ]; then
	usage
else
	echo ""
	echo "Deleting launch template $1 ..."
	# Check if launch template exists
	CMD="aws ec2 describe-launch-templates --launch-template-ids $1 > /dev/null"
	eval "$CMD"
	if [ "$?" == "0" ]; then
		CMD="aws ec2 delete-launch-template --launch-template-id $1"
		eval "$CMD"
		echo ""
		if [ "$?" == "0" ]; then
			echo "Launch template $1 deleted."
		else
			echo "Failed to delete launch template $1"
		fi
	fi
	echo ""
fi
