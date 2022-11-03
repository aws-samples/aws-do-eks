#!/bin/bash

echo ""
echo "To enable cluster migration to Karpenter"
echo "The cluster aws-auth configmap needs to be patched ..."
echo "Add the following to your existing aws-auth config map: "
echo "
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::${AWS_ACCOUNT_ID}:role/KarpenterInstanceNodeRole
      username: system:node:{{EC2PrivateDNSName}}"
