#!/bin/bash

. ./nodegroup.conf

SG=$(aws eks describe-cluster --region $REGION --name $CLUSTER | jq -r '.cluster.resourcesVpcConfig.clusterSecurityGroupId')
#aws ec2 authorize-security-group-egress --group-id $SG --protocol -1 --port all --source-group $S

cat << EOF
{
    "BlockDeviceMappings": [{"DeviceName": "/dev/xvda","Ebs": {"DeleteOnTermination": true,"VolumeSize": 500,"VolumeType": "gp3"}}], 
    "NetworkInterfaces":[
        {"DeviceIndex": 0, "NetworkCardIndex": 0, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 1, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},  
        {"DeviceIndex": 1, "NetworkCardIndex": 2, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},  
        {"DeviceIndex": 1, "NetworkCardIndex": 3, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},  
        {"DeviceIndex": 1, "NetworkCardIndex": 4, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},  
        {"DeviceIndex": 1, "NetworkCardIndex": 5, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},  
        {"DeviceIndex": 1, "NetworkCardIndex": 6, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},  
        {"DeviceIndex": 1, "NetworkCardIndex": 7, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},  
        {"DeviceIndex": 1, "NetworkCardIndex": 8, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 9, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 10, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 11, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 12, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 13, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 14, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 15, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 16, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 17, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 18, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 19, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 20, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 21, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 22, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 23, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 24, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 25, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 26, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 27, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 28, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 29, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 30, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"},
        {"DeviceIndex": 1, "NetworkCardIndex": 31, "Groups":["$SG"], "DeleteOnTermination":true, "InterfaceType": "efa"}
    ],
    "ImageId":"$AMI",
    "InstanceType":"p5.48xlarge", 
    "KeyName": "$SSH_KEY_NAME",
    "UserData":"$(./userdata.sh | base64 -w 0)",
    "CapacityReservationSpecification": {
        "CapacityReservationTarget": {
            "CapacityReservationId": "$CAPACITY_RESERVATION_ID"
        }
    },
    "Placement": {
        "GroupName": "$PLACEMENT_GROUP_NAME"
    }
}
EOF

