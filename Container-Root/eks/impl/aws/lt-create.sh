#!/bin/bash

source ./nodegroup.conf

./lt-generate.sh > lt.json

CMD="aws ec2 --region $REGION create-launch-template --launch-template-name $LAUNCH_TEMPLATE_NAME --version-description v${LAUNCH_TEMPLATE_VERSION} --launch-template-data file://lt.json" 

echo "$CMD"
eval "$CMD"

rm -rf lt.json

