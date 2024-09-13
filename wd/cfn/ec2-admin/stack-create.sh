#!/bin/bash

aws cloudformation create-stack --stack-name AdminInstance --template-body file://AdminInstance.json --capabilities CAPABILITY_IAM 

