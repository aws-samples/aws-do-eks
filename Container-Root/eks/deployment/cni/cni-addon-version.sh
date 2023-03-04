#!/bin/bash

. /eks/eks.conf

aws eks describe-addon --cluster-name $CLUSTER_NAME --addon-name vpc-cni --query addon.addonVersion --output text

