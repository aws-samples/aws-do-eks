#!/bin/bash

# This script is not fully automated. Follow the steps from this post
# https://aws.amazon.com/blogs/opensource/using-fsx-lustre-csi-driver-amazon-eks/
# Also refer to: https://docs.aws.amazon.com/eks/latest/userguide/fsx-csi.html
# and https://github.com/kubernetes-sigs/aws-fsx-csi-driver
# If dynamic provisioning does not work, use static provisioning instructions from here
# https://github.com/kubernetes-sigs/aws-fsx-csi-driver/blob/master/examples/kubernetes/static_provisioning/README.md


echo ""

echo "Creating FSX Policy ..."
POLICY_ARN=$(aws iam create-policy --policy-name fsx-csi --policy-document file://./fsx-policy.json --query "Policy.Arn" --output text)
echo "POLICY_ARN=$POLICY_ARN"

echo "Attaching FSX Policy to Instance Role ..."
INSTANCE_ROLE_NAME=$(aws cloudformation describe-stacks --stack-name eksctl--driver-nodegroup-ng-1 --output text --query "Stacks[0].Outputs[1].OutputValue" | sed -e 's/.*\///g')

echo "INSTANCE_ROLE_NAME=$INSTANCE_ROLE_NAME"
aws iam attach-role-policy --policy-arn ${POLICY_ARN} --role-name ${INSTANCE_ROLE_NAME}

echo "Installing FSx CSI driver ..."
kubectl create -k "github.com/kubernetes-sigs/aws-fsx-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"

echo "Showing pods in kube-system namespace ..."
kubectl -n kube-system get pods

VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=eksctl-fsx-csi-driver/VPC" --query "Vpcs[0].VpcId" --output text)

SUBNET_ID=$(aws ec2 describe-subnets --filters "[{\"Name\": \"vpc-id\",\"Values\": [\"$VPC_ID\"]},{\"Name\": \"tag:aws:cloudformation:logical-id\",\"Values\": [\"SubnetPrivateUSWEST2A\"]}]"  --query "Subnets[0].SubnetId" --output text)

SECURITY_GROUP_ID=$(aws ec2 create-security-group --group-name eks-fsx-security-group --vpc-id ${VPC_ID} --description "FSx for Lustre Security Group" --query "GroupId" --output text)

aws ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol tcp --port 988 --cidr 192.168.0.0/16

cat > fsx-storage-class.yaml <<EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: fsx-sc
provisioner: fsx.csi.aws.com
parameters:
  subnetId: ${SUBNET_ID}
  securityGroupIds: ${SECURITY_GROUP_ID}
EOF

kubectl apply -f fsx-storage-class.yaml
