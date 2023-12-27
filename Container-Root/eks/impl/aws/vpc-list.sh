#!/bin/bash

aws ec2 describe-vpcs --query "Vpcs[*].{Name:Tags[?Key=='Name']|[0].Value,CidrBlock:CidrBlock,VpcId:VpcId}" --output table

