#!/bin/bash

aws cloudformation create-stack --stack-name ManagementInstance --template-body file://ManagementInstance.json --capabilities CAPABILITY_IAM --parameters ParameterKey="REGION",ParameterValue="us-west-2"

