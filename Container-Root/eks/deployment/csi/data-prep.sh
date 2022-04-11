#!/bin/bash
# This script assumes two arguments 
# This script is used by efs-data-prep-pod.yaml

# first argument - name of s3 bucket
# example: s3://YOUR_S3_BUCKET_WITH_DATA

# second argument - mount path & target dir
# example: /efs-shared/DATA/
# NOTE: if the DATA directory doesn't exist, it will be created by `s3 cp` command

echo "S3 bucket for downloading the data - ${1}"
echo "Mount path - ${2}"

echo "copying ......."
aws s3 cp ${1} ${2} --recursive

echo "done ......"
echo $(ls $2)
