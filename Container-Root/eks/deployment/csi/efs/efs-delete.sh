#!/bin/bash

echo ""
FILE_SYSTEM_ID=$(aws efs describe-file-systems --query 'FileSystems[*].FileSystemId' --output json | jq -r .[0] )
if [ "$FILE_SYSTEM_ID" == "" ]; then
        echo "No EFS Filesystems found."
else
        echo "Deleting EFS mount targets for File System $FILE_SYSTEM_ID ..."
        MOUNT_TARGETS="$(aws efs describe-mount-targets --file-system-id $FILE_SYSTEM_ID --query MountTargets[].MountTargetId --output text)"
        MT=$(echo $MOUNT_TARGETS)
        for t in $MT; do echo Deleting mount target $t; aws efs delete-mount-target --mount-target-id $t; done 
        sleep 10
        echo "Deleting EFS file system $FILE_SYSTEM_ID ..."
        aws efs delete-file-system --file-system-id $FILE_SYSTEM_ID
fi

echo ""
echo 'Done ...'
