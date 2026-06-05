#!/bin/bash

echo ""
echo "Removing do-hf pod ..."
kubectl delete pod do-hf --force --grace-period=0

