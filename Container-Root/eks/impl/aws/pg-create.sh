#!/bin/bash

. ./nodegroup.conf

aws ec2 create-placement-group --group-name ${PLACEMENT_GROUP_NAME} --strategy cluster --tag-specifications 'ResourceType=placement-group,Tags={Key=purpose,Value=performance}'

