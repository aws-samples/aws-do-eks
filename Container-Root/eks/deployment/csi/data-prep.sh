#!/bin/bash
# This script assumes two arguments 
# This script is used by xxx-data-prep-pod.yaml

# first argument - name of s3 bucket
# example: s3://YOUR_S3_BUCKET_WITH_DATA

# second argument - mount path & target dir
# example: /efs-shared/DATA/

echo "S3 bucket for downloading the data - ${1}"
echo "Mount path - ${2}"

echo "copying ......."
#aws s3 sync ${1} ${2} --quiet

python3 imagenet_data_prep.py

echo "done ......"
echo $(ls $2)
