#!/bin/bash

source .env

#torchx run -s kubernetes -c queue=default,image_repo=${REGISTRY}${IMAGE} dist.ddp --gpu 0 --memMB 4096 --script idle.py data

# etcd is required when using dist_ddp.py:ddp
# etcd is not required when using dist.ddp

#torchx run -s kubernetes -c queue=default,image_repo=${REGISTRY}${IMAGE} dist.ddp --debug False -j 1:2x1 --gpu 1 --memMB 40960 --script /workspace/imagenet-elastic.py -- --arch resnet18 --epochs 10 --batch-size 32 --print-freq 10 --workers 0 /workspace/data/tiny-imagenet-200

torchx run -s kubernetes -c queue=default,image_repo=${REGISTRY}${IMAGE} ./dist_ddp.py:ddp --debug False -j 1:2x1 --gpu 1 --memMB 40960 --script /workspace/imagenet-elastic.py -- --arch resnet18 --epochs 10 --batch-size 32 --print-freq 10 --workers 0 /workspace/data/tiny-imagenet-200

