#!/bin/bash

kubectl delete -f ./fsx-storage-class.yaml

kubectl delete -k "github.com/kubernetes-sigs/aws-fsx-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"

aws ec2 delete-security-group --group-id ${SECURITY_GROUP_ID}

aws iam detach-role-policy --role-name ${INSTANCE_ROLE_NAME} --policy-arn ${POLICY_ARN}

