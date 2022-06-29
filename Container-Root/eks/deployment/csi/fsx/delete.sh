#!/bin/bash

. fsx.conf

# This script removes the integration of your EKS cluster with FSx
# Please note that deleting any dynamically provisioned FSx volumes
# destroys the volumes and the data stored in them

# Storage class
kubectl delete -f ./fsx-storage-class.yaml
rm -f ./fsx-storage-class.yaml

# Security group
echo ""
echo "Checking security group ${FSX_SECURITY_GROUP_NAME} ..."
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --query SecurityGroups[?GroupName=="'${FSX_SECURITY_GROUP_NAME}'"].{GroupId:GroupId} --output text)
if [ "$SECURITY_GROUP_ID" == "" ]; then
        echo "Not found."
else
        echo "Found."
        echo "SECURITY_GROUP_ID=${SECURITY_GROUP_ID}"
        echo "Deleting ..."
        aws ec2 delete-security-group --group-id ${SECURITY_GROUP_ID}
fi

# FSx CSI driver
kubectl delete -k "github.com/kubernetes-sigs/aws-fsx-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"

# FSx Policy
echo ""
echo "Checking FSx Policy ${FSX_POLICY_NAME} ..."
POLICY_ARN=$(aws iam list-policies --query Policies[?PolicyName=="'${FSX_POLICY_NAME}'"].{Arn:Arn} --output text)
echo ""
if [ "$POLICY_ARN" == "" ]; then
        echo "Policy does not exist."
else
        echo "Policy ${FSX_POLICY_NAME} found"
        echo "POLICY_ARN=$POLICY_ARN"
        # Detach policy from EKS Instance Profiles
        echo ""
        echo "Checking instance profiles ..."
        for index in ${!EKS_INSTANCE_PROFILE_NAMES[@]}; do
                EKS_INSTANCE_PROFILE_NAME=${EKS_INSTANCE_PROFILE_NAMES[$index]}
                echo ""
                echo "Instance profile ${EKS_INSTANCE_PROFILE_NAME} ..."
                INSTANCE_PROFILE=$(aws iam list-instance-profiles --query InstanceProfiles[?InstanceProfileName=="'${EKS_INSTANCE_PROFILE_NAME}'"].{InstanceProfileName:InstanceProfileName} --output text)
                if [ "$INSTANCE_PROFILE" == "" ]; then
                        echo "Not found."
                        echo "Please check fsx.conf and try again."
                        echo "The configured instance profile must exist"
                        echo "Describe one of the EKS instances in each node group that should have access to FSx "
                        echo "and find its attached instance profile. Update the array in fsx.conf and try again."
                        exit 1
                else
                        echo "Found."
                        echo "Getting instance profile role ..."
                        ROLE_NAME=$(aws iam get-instance-profile --instance-profile-name ${INSTANCE_PROFILE} --query InstanceProfile.Roles[0].RoleName --output text)
                        echo "Detaching FSx Policy from role ${ROLE_NAME} ..."
                        aws iam detach-role-policy --role-name ${ROLE_NAME} --policy-arn ${POLICY_ARN}
                fi
        done
        echo ""
        echo "Deleting policy ${FSX_POLICY_NAME} ..."
        aws iam delete-policy --policy-arn ${POLICY_ARN}
fi

kubectl get sc

