#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

echo ""
echo "Listing launch templates ..."
echo ""
CMD="aws ec2 describe-launch-templates --query 'LaunchTemplates[*].{LaunchTemplateId:LaunchTemplateId,LaunchTemplateName:LaunchTemplateName,DefaultVersion:DefaultVersionNumber}' --output table"
echo "$CMD"
eval "$CMD"

