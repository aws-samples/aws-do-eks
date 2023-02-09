#!/bin/bash

# Distributed training script
echo "Container-Root/train.sh executed"

rm -r /tmp/test-clm; NCCL_P2P_DISABLE=1 CUDA_VISIBLE_DEVICES=0,1 \
        python -m torch.distributed.launch --nproc_per_node 2 /run_clm.py \
        --model_name_or_path gpt2 --dataset_name wikitext --dataset_config_name wikitext-2-raw-v1 \
        --do_train --output_dir /tmp/test-clm --per_device_train_batch_size 4 --max_steps 200
