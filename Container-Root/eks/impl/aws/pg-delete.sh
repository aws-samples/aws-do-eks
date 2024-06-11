#!/bin/bash

. ./nodegroup.conf

aws ec2 delete-placement-group --group-name $PLACEMENT_GROUP_NAME

