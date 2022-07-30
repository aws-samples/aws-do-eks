#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

echo ""
echo "Describing data prep pod ..."
kubectl describe pod efs-data-prep-pod

echo ""
echo "Showing status of data prep pod ..."
kubectl get pods | grep data-prep

