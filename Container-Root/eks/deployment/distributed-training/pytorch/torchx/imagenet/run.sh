#!/bin/bash

source .env

#torchx run -s kubernetes -c queue=default,image_repo=${REGISTRY}${IMAGE} dist.ddp --gpu 0 --memMB 4096 --script idle.py data
#torchx run -s kubernetes -c queue=default,image_repo=${REGISTRY}${IMAGE} dist.ddp --gpu 0 --memMB 8192 --script /workspace/elastic/examples/imagenet/main.py /workspace/data/tiny-imagenet-200
torchx run -s kubernetes -c queue=default,image_repo=${REGISTRY}${IMAGE} dist.ddp -j 2x1 --gpu 1 --memMB 40960 --script /workspace/main.py -- --dist-backend gloo --arch resnet18 --epochs 10 --batch-size 32 --checkpoint-file /workspace/data/checkpoint.pth.tar --print-freq 10 --workers 0 /workspace/data/tiny-imagenet-200


