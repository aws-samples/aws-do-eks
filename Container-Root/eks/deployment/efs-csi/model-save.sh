#!/bin/bash
# first argument - name of s3 bucket
# second argument - mount path

echo "S3 bucket for downloading the data - ${1}"
echo "Mount path - ${2}"

DIR="model-"$(date '+%Y-%m-%d_%H:%M:%S')

cd ${2}
mkdir $DIR
mv model_best.pth.tar $DIR
mv checkpoint.pth.tar $DIR

aws s3 cp --recursive $DIR ${1}/$DIR
