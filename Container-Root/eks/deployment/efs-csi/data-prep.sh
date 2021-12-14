#!/bin/bash
# first argument - name of s3 bucket
# second argument - mount path

echo "S3 bucket for downloading the data - ${1}"
echo "Mount path - ${2}"

# NOTE: THIS TAKES WAY TOO LONG. THERE SHOULD BE A BETTER SOLUTION
cd $2
mkdir ILSVRC

echo "copying ......."
aws s3 cp ${1}/ILSVRC ILSVRC/ --recursive --quite

echo "done ......"
echo $(ls $2)
