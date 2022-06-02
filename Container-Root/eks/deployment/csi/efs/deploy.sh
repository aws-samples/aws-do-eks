#!/bin/bash

# This script mostly follows this eks workshop
# https://www.eksworkshop.com/beginner/190_efs/launching-efs/

# if the pvc already exists, exit
PV_EXISTS=$(kubectl get pv -o json | jq --raw-output '.items[].spec.storageClassName')
for pv in ${PV_EXISTS}
do
    if [ "$pv" == "efs-sc" ]; then
        echo "Persistant Volume exists"
        kubectl get pv
        exit 0
    fi
done

# Assign file system id. Create EFS file system if needed. If more than one filesystem exists, take first one in the list
FILE_SYSTEM_ID=$(aws efs describe-file-systems --query 'FileSystems[*].FileSystemId' --output json | jq -r .[0])
if [ "$FILE_SYSTEM_ID" == "null" ]; then
        echo ""
        echo "No EFS file system found. Setting up new EFS File System ..."
        ./efs-create.sh
        FILE_SYSTEM_ID=$(aws efs describe-file-systems --query 'FileSystems[*].FileSystemId' --output json | jq -r .[0])
fi
echo 'EFS volume id' $FILE_SYSTEM_ID

echo ""
echo "Deploying EFS CSI Driver ..."
kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.3"
sleep 5
kubectl get pods -n kube-system | grep efs

echo ""
echo "Generating efs-sc.yaml ..."
cat efs-sc.yaml.template | sed -e "s/EFS_VOLUME_ID/$FILE_SYSTEM_ID/g" > efs-sc.yaml
echo ""
echo "Applying efs-sc.yaml ..."
kubectl apply -f efs-sc.yaml
kubectl get sc

echo ""
echo "Generating efs-pv.yaml ..."
cat efs-pv.yaml.template | sed -e "s/EFS_VOLUME_ID/$FILE_SYSTEM_ID/g" > efs-pv.yaml
echo "Applying efs-pv.yaml ..."
kubectl apply -f efs-pv.yaml
sleep 10
kubectl get pv

echo ""
echo "Done ..."
