#!/bin/bash

# Get cluster name
if [ -f "/eks/conf/env.conf" ]; then
	pushd /eks
	CLUSTER_NAME=$(/eks/eks-name.sh)
	popd
fi

if [ "$CLUSTER_NAME" == "" ]; then
	echo ""
else
	echo "CLUSTER_NAME=$CLUSTER_NAME"
cat <<EOF | kubectl apply -f -
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: default
spec:
  requirements:
    - key: karpenter.sh/capacity-type
      operator: In
      values: ["spot", "on-demand"]
    - key: karpenter.k8s.aws/instance-category
      operator: In
      values: ["c", "m", "r", "g", "p"]
    - key: karpenter.k8s.aws/instance-generation
      operator: Gt
      values:
      - "2"
#  limits:
#    resources:
#      cpu: 1000
  providerRef:
    name: default
  ttlSecondsAfterEmpty: 30
---
apiVersion: karpenter.k8s.aws/v1alpha1
kind: AWSNodeTemplate
metadata:
  name: default
spec:
  instanceProfile: KarpenterNodeInstanceProfile-${CLUSTER_NAME} 
  subnetSelector:
    karpenter.sh/discovery: ${CLUSTER_NAME}
  securityGroupSelector:
    karpenter.sh/discovery: ${CLUSTER_NAME}
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 80Gi
        volumeType: gp3
        deleteOnTermination: true
EOF
fi
