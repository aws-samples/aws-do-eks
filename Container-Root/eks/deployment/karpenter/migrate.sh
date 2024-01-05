#!/bin/bash

# Note: this script is created following instructions from https://karpenter.sh/v0.16.3/getting-started/migrating-from-cas/

# Source eks.conf
if [ -f ./eks.conf ]; then
        . ./eks.conf
elif [ -f /eks/eks.conf ]; then
        . /eks/eks.conf
elif [ -f ../../eks.conf ]; then
        . ../../eks.conf
else
        echo ""
        echo "Error: Could not locate eks.conf"
fi

if [ "$CLUSTER_NAME" == "" ]; then
        echo ""
        echo "CLUSTER_NAME is not set, exiting ..."
else

        echo ""
        echo "Migrating current EKS cluster ($CLUSTER_NAME) from AutoScaler to Karpenter ..."

        echo ""
        echo "Creating trust policy document node-trust-pulicy.json ..."
echo '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}' > node-trust-policy.json

        echo ""
        echo "Creating IAM role KarpenterInstanceNodeRole ..."
        aws iam create-role --role-name KarpenterInstanceNodeRole \
        --assume-role-policy-document file://node-trust-policy.json

        echo ""
        echo "Attaching managed policies to KarpenterInstanceNodeRole ..."
        aws iam attach-role-policy --role-name KarpenterInstanceNodeRole \
        --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy

        aws iam attach-role-policy --role-name KarpenterInstanceNodeRole \
        --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy

        aws iam attach-role-policy --role-name KarpenterInstanceNodeRole \
        --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

        aws iam attach-role-policy --role-name KarpenterInstanceNodeRole \
        --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

        echo ""
        echo "Creating instance profile KarpenterInstanceProfile ..."
        aws iam create-instance-profile \
        --instance-profile-name KarpenterInstanceProfile

        echo ""
        echo "Attaching IAM role KarpenterInstanceNodeRole to instance profile KarpenterInstanceProfile ..."
        aws iam add-role-to-instance-profile \
        --instance-profile-name KarpenterInstanceProfile \
        --role-name KarpenterInstanceNodeRole

        echo ""
        echo "Setting cluster variables ..."
        CLUSTER_ENDPOINT="$(aws eks describe-cluster \
        --name ${CLUSTER_NAME} --query "cluster.endpoint" \
        --output text)"
        echo CLUSTER_ENDPOINT=$CLUSTER_ENDPOINT
        OIDC_ENDPOINT="$(aws eks describe-cluster --name ${CLUSTER_NAME} \
        --query "cluster.identity.oidc.issuer" --output text)"
        echo OIDC_ENDPOINT=$OIDC_ENDPOINT
        AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' \
        --output text)
        echo AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID

        echo ""
        echo "Creating controller trust policy document controller-trust-policy.json ..."
echo "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
        {
            \"Effect\": \"Allow\",
            \"Principal\": {
                \"Federated\": \"arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_ENDPOINT#*//}\"
            },
            \"Action\": \"sts:AssumeRoleWithWebIdentity\",
            \"Condition\": {
                \"StringEquals\": {
                    \"${OIDC_ENDPOINT#*//}:aud\": \"sts.amazonaws.com\",
                    \"${OIDC_ENDPOINT#*//}:sub\": \"system:serviceaccount:karpenter:karpenter\"
                }
            }
        }
    ]
}" > controller-trust-policy.json

        echo ""
        echo "Creating IAM role KarpenterControllerRole-${CLUSTER_NAME} ..."
        aws iam create-role --role-name KarpenterControllerRole-${CLUSTER_NAME} \
        --assume-role-policy-document file://controller-trust-policy.json

        echo ""
        echo "Creating controller policy document controller-policy.json ..."
echo '{
    "Statement": [
        {
            "Action": [
                "ssm:GetParameter",
                "iam:PassRole",
                "ec2:DescribeImages",
                "ec2:RunInstances",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeLaunchTemplates",
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceTypes",
                "ec2:DescribeInstanceTypeOfferings",
                "ec2:DescribeAvailabilityZones",
                "ec2:DeleteLaunchTemplate",
                "ec2:CreateTags",
                "ec2:CreateLaunchTemplate",
                "ec2:CreateFleet",
                "ec2:DescribeSpotPriceHistory",
                "pricing:GetProducts"
            ],
            "Effect": "Allow",
            "Resource": "*",
            "Sid": "Karpenter"
        },
        {
            "Action": "ec2:TerminateInstances",
            "Condition": {
                "StringLike": {
                    "ec2:ResourceTag/Name": "*karpenter*"
                }
            },
            "Effect": "Allow",
            "Resource": "*",
            "Sid": "ConditionalEC2Termination"
        }
    ],
    "Version": "2012-10-17"
}' > controller-policy.json

        echo ""
        echo "Attaching policy KarpenterControllerPolicy-${CLUSTER_NAME}  to IAM role KarpenterControllerRole-${CLUSTER_NAME} ..."
        aws iam put-role-policy --role-name KarpenterControllerRole-${CLUSTER_NAME} \
        --policy-name KarpenterControllerPolicy-${CLUSTER_NAME} \
        --policy-document file://controller-policy.json

        echo ""
        echo "Adding tags to subnets ..."
        for NODEGROUP in $(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} --query 'nodegroups' --output text); do
                aws ec2 create-tags --tags "Key=karpenter.sh/discovery,Value=${CLUSTER_NAME}" \
                --resources $(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} \
                --nodegroup-name $NODEGROUP --query 'nodegroup.subnets' --output text )
        done

        echo ""
        echo "Adding tags to security groups ..."
        NODEGROUP=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} \
        --query 'nodegroups[1]' --output text)
	echo "NODEGROUP=$NODEGROUP"

        LAUNCH_TEMPLATE=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} \
        --nodegroup-name ${NODEGROUP} --query 'nodegroup.launchTemplate.{id:id,version:version}' \
        --output text | tr -s "\t" ",")
	echo "LAUNCH_TEMPLATE=$LAUNCH_TEMPLATE"

        # If your EKS setup is configured to use only Cluster security group, then please execute -
        #SECURITY_GROUPS=$(aws eks describe-cluster \
        #--name ${CLUSTER_NAME} --query "cluster.resourcesVpcConfig.clusterSecurityGroupId")

        # If your setup uses the security groups in the Launch template of a managed node group, then :
        SECURITY_GROUPS=$(aws ec2 describe-launch-template-versions \
        --launch-template-id ${LAUNCH_TEMPLATE%,*} --versions ${LAUNCH_TEMPLATE#*,} \
        --query 'LaunchTemplateVersions[0].LaunchTemplateData.[NetworkInterfaces[0].Groups||SecurityGroupIds]' \
        --output text)
	echo "SECURITY_GROUPS=$SECURITY_GROUPS"

        aws ec2 create-tags \
        --tags "Key=karpenter.sh/discovery,Value=${CLUSTER_NAME}" \
        --resources ${SECURITY_GROUPS}

        echo ""
        echo "Patching cluster aws-auth configmap ..."
	echo "Add the following to your existing aws-auth config map: "
        echo "
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::${AWS_ACCOUNT_ID}:role/KarpenterInstanceNodeRole
      username: system:node:{{EC2PrivateDNSName}}"


        #kubectl -n kube-system patch configmap aws-auth --type merge \
        #-p '{"data": { "mapRoles": "- groups:\n  - system:bootstrappers\n  -system:nodes\n  rolearn: arn:aws:iam::${AWS_ACCOUNT_ID}:role/KarpenterInstanceNodeRole\n  username: system:node:{{EC2PrivateDNSName}}\n"}}'
        #or
        kubectl edit configmap aws-auth -n kube-system

        echo ""
        export KARPENTER_VERSION=$CLUSTER_KARPENTER_VERSION
        echo "Deploying Karpenter version $KARPENTER_VERSION ..."
        helm repo add karpenter https://charts.karpenter.sh/
        helm repo update
        helm template --namespace karpenter \
        karpenter karpenter/karpenter \
        --set aws.defaultInstanceProfile=KarpenterInstanceProfile \
        --set clusterEndpoint="${CLUSTER_ENDPOINT}" \
        --set clusterName=${CLUSTER_NAME} \
        --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::${AWS_ACCOUNT_ID}:role/KarpenterControllerRole-${CLUSTER_NAME}" \
        --version ${KARPENTER_VERSION} > karpenter.yaml

	echo ""
	echo "Deploying Karpenter helm chart ..."
	export KARPENTER_IAM_ROLE_ARN=arn:aws:iam::${AWS_ACCOUNT_ID}:role/KarpenterControllerRole-${CLUSTER_NAME}
	echo $KARPENTER_IAM_ROLE_ARN

	helm upgrade --install --namespace karpenter --create-namespace \
  	karpenter karpenter/karpenter \
  	--version ${KARPENTER_VERSION} \
  	--set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${KARPENTER_IAM_ROLE_ARN} \
  	--set clusterName=${CLUSTER_NAME} \
  	--set clusterEndpoint=${CLUSTER_ENDPOINT} \
  	--set aws.defaultInstanceProfile=KarpenterInstanceProfile \
	--wait

        #Optionally set affinity for karpenter pods
        #affinity:
        #  nodeAffinity:
        #    requiredDuringSchedulingIgnoredDuringExecution:
        #      nodeSelectorTerms:
        #      - matchExpressions:
        #        - key: karpenter.sh/provisioner-name
        #          operator: DoesNotExist
        #      - matchExpressions:
        #        - key: eks.amazonaws.com/nodegroup
        #          operator: In
        #          values:
        #          - ${NODEGROUP}

        #kubectl create namespace karpenter
        #kubectl create -f \
        #        https://raw.githubusercontent.com/aws/karpenter/${KARPENTER_VERSION}/charts/karpenter/crds/karpenter.sh_provisioners.yaml
        #kubectl apply -f karpenter.yaml

        echo ""
        echo "Verifying Karpenter deployment ..."
        kubectl logs -n karpenter -c controller -l app.kubernetes.io/name=karpenter

        echo ""
        echo "Generating default provisioner manifest ..."
        echo "karpenter-provisioner-default.yaml"
        echo "
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: default
spec:
  provider:
    subnetSelector:
      karpenter.sh/discovery: ${CLUSTER_NAME}
    securityGroupSelector:
      karpenter.sh/discovery: ${CLUSTER_NAME}" > karpenter-provisioner-default.yaml
        cat ./karpenter-provisioner-default.yaml

        echo ""
        echo "If you wish to deploy Karpenter's default provisioner, execute:"
        echo "kubectl apply -f ./karpenter-provisioner-default.yaml"
        echo ""

fi
