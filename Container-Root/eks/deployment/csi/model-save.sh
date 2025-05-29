#!/bin/bash
# first argument - name of s3 bucket where the model should be saved
# example: s3://YOUR_S3_BUCKET_WITH_DATA/MODELS/
# second argument - shared mount path where the model & checkpoint files are residing
# example: /efs-shared/

echo "S3 bucket - ${1}"
echo "Mount path - ${2}"

DIR="model-"$(date '+%Y-%m-%d_%H:%M:%S')

cd ${2}
mkdir $DIR
mv model_best.pth.tar $DIR
mv checkpoint.pth.tar $DIR

aws s3 cp --recursive $DIR ${1}/$DIR
