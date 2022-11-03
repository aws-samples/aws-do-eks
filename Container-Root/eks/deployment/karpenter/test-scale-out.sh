#!/bin/bash

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inflate
spec:
  replicas: 0
  selector:
    matchLabels:
      app: inflate
  template:
    metadata:
      labels:
        app: inflate
    spec:
      nodeSelector:
        beta.kubernetes.io/instance-type: "g4dn.8xlarge"
      terminationGracePeriodSeconds: 0
      containers:
        - name: inflate
          image: public.ecr.aws/eks-distro/kubernetes/pause:3.2
          resources:
            limits:
              nvidia.com/gpu: 1
#              vpc.amazonaws.com/efa: 1
            requests:
#              cpu: 30000m
              nvidia.com/gpu: 1
#              vpc.amazonaws.com/efa: 1
EOF

./scale.sh 2
