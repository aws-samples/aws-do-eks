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
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
spec:
  template:
    metadata:
      labels:
        cluster-name: $CLUSTER_NAME
      annotations:
        purpose: "karpenter-example"
    spec:
      nodeClassRef:
        apiVersion: karpenter.k8s.aws/v1beta1
        kind: EC2NodeClass
        name: default
      requirements:
        - key: "karpenter.sh/capacity-type"
          operator: In
          values: ["spot", "on-demand"]
        - key: "karpenter.k8s.aws/instance-category"
          operator: In
          values: ["c", "m", "r", "g", "p"]
        - key: "karpenter.k8s.aws/instance-generation"
          operator: Gt
          values: ["2"]
  disruption:
    consolidationPolicy: WhenUnderutilized
    #consolidationPolicy: WhenEmpty
    #consolidateAfter: 30s
    expireAfter: 720h
---
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}"
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}"
  role: "KarpenterNodeRole-${CLUSTER_NAME}"
  tags:
    app: autoscaling-test
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 80Gi
        volumeType: gp3
        iops: 10000
        deleteOnTermination: true
        throughput: 125
  detailedMonitoring: true
EOF
fi

