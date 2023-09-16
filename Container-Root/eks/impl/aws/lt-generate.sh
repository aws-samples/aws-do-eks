#!/bin/bash

. ./nodegroup.conf

SG=$(aws eks describe-cluster --region $REGION --name $CLUSTER | jq -r '.cluster.resourcesVpcConfig.clusterSecurityGroupId')
#aws ec2 authorize-security-group-egress --group-id $SG --protocol -1 --port all --source-group $S

cat << EOF
{
    "BlockDeviceMappings": [{"DeviceName": "/dev/xvda","Ebs": {"DeleteOnTermination": true,"VolumeSize": 500,"VolumeType": "gp3"}}], 
    "NetworkInterfaces":[
        {"DeviceIndex": 0, "NetworkCardIndex": 0, "Groups":["$SG"],"DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 4, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},  
        {"DeviceIndex": 1, "NetworkCardIndex": 8, "Groups":["$SG"],"DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 12, "Groups":["$SG"],"DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 16, "Groups":["$SG"],"DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 20, "Groups":["$SG"],"DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 24, "Groups":["$SG"],"DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 28, "Groups":["$SG"],"DeleteOnTermination":true, "InterfaceType": "efa"}
    ],
    "ImageId":"$AMI",
    "InstanceType":"p5.48xlarge", 
    "KeyName": "$SSH_KEY_NAME",
    "UserData":"$(./userdata.sh | base64 -w 0)"
}
EOF

