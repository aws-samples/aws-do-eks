#!/bin/bash

aws ec2 describe-placement-groups --query "PlacementGroups[*].{Name:GroupName,ID:GroupId,Strategy:Strategy}" --output table


