#!/bin/bash
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
else
cat <<EOF > provisioner-efa.yaml 
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: default
spec:
  requirements:
    - key: karpenter.sh/capacity-type
      operator: In
      values: ["on-demand"]
    - key: node.kubernetes.io/instance-type
      operator: In
      values:
      - g4dn.8xlarge
 #     - g5.48xlarge
 #     - p3dn.24xlarge
    - key: "topology.kubernetes.io/zone"
      operator: In
      values: ["us-west-2b"]
  limits:
    resources:
      cpu: 1000
  providerRef:
    name: default
#    subnetSelector:
#      karpenter.sh/discovery: ${CLUSTER_NAME}
#      karpenter.sh/network: efa
#    securityGroupSelector:
#      karpenter.sh/discovery: ${CLUSTER_NAME}
  ttlSecondsAfterEmpty: 30
---
apiVersion: karpenter.k8s.aws/v1alpha1
kind: AWSNodeTemplate
metadata:
  name: default
spec:
  subnetSelector:
    karpenter.sh/discovery: ${CLUSTER_NAME}
#    karpetner.sh/network: efa
#  securityGroupSelector: 
#    karpenter.sh/discovery: ${CLUSTER_NAME}
#    karpenter.sh/network: efa
  launchTemplate: ${LAUNCH_TEMPLATE_NAME}
EOF
fi

kubectl apply -f ./provisioner-efa.yaml

