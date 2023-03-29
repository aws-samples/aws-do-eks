#!/bin/bash

source .env

if [ ! -d ./imagenet ]; then
	./checkout.sh
fi

torchx run -s kubernetes -c queue=default,image_repo=${REGISTRY}${IMAGE} ./dist_ddp.py:ddp --env NCCL_P2P_DISABLE=1,find_unused_parameters=False  --debug False -j 2x1 --gpu 1 --memMB 40960 --script ./imagenet/train.py -- --epochs=100 --output_path=/tmp/torchx/train --log_path=/tmp/torchx/logs --skip_export

