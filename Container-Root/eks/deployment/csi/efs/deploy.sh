#!/bin/bash

# This script mostly follows this eks workshop
# https://www.eksworkshop.com/beginner/190_efs/launching-efs/

# if the pvc already exists, don't run this scritp
PV_EXISTS=$(kubectl get pv -o json | jq --raw-output '.items[].spec.storageClassName')
for pv in ${PV_EXISTS}
do
    if [ "$pv" == "efs-sc" ]; then
        echo "Persistant Volume exists"
        kubectl get pv
        exit 0
    fi
done

# This assumes that the file system has already been created and there is only one file system
FILE_SYSTEM_ID=$(aws efs describe-file-systems --query 'FileSystems[*].FileSystemId' --output text)
echo 'EFS volume id' $FILE_SYSTEM_ID

kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.3"
sleep 10

echo "Applying efs-pvc.yaml ..."

# If the yaml file does not have the EFS file id, then update the file
if grep -Fq "EFS_VOLUME_ID" efs-pvc.yaml; then
    echo "Updating yaml"
    sed -i "s/EFS_VOLUME_ID/$FILE_SYSTEM_ID/g" efs-pvc.yaml
fi

kubectl apply -f efs-pvc.yaml
sleep 20

kubectl get pv

echo 'Starting test pod ...'
kubectl apply -f efs-share-test.yaml

echo "Done ..."
