#!/bin/bash

SHARED_FOLDER=/efs-shared
model_garden_path=/Model-References
bert_path=${model_garden_path}/PyTorch/nlp/pretraining/deepspeed-bert
data_dir=${SHARED_FOLDER}/data
output_dir=${SHARED_FOLDER}/results

timestamp=$(date -d "today" +"%Y%m%d"-"%H%M")

# Params: run_pretraining
DATA_DIR=${data_dir}/hdf5_lower_case_1_seq_len_128_max_pred_20_masked_lm_prob_0.15_random_seed_12345_dupe_factor_5/wikicorpus_en
MODEL_CONFIG=${bert_path}/scripts/bert_1.5b_config.json
DS_CONFIG=${bert_path}/scripts/deepspeed_config_bert_1.5b.json
RESULTS_DIR=${output_dir}/deepspeed/bert_1.5b/${timestamp}
MAX_SEQ_LENGTH=128
NUM_STEPS_PER_CP=1000000
MAX_STEPS=155000
LR=0.0015
WARMUP=0.05
CONST=0.25


MPI_HOST_FILE=$OMPI_MCA_orte_default_hostfile
DS_HOSTSFILE=/job/hostfile
NGPU_PER_NODE=$OMPI_MCA_orte_set_default_slots

mkdir -p /job
touch $DS_HOSTSFILE

echo ""
date
echo "Creating DeepSpeed hostfile from MPI, checking ssh connections..."

for worker in $(cat $MPI_HOST_FILE)
do
    echo "Trying to test ssh connection to worker: $worker"
    until ssh ${worker} hostname -I
    do
        echo "Sleeping 5 seconds and trying again"
        sleep 5
    done
    echo "$worker slots=$NGPU_PER_NODE" | cat >> $DS_HOSTSFILE
done

echo "DeepSpeed hostfile $DS_HOSTSFILE:"
cat $DS_HOSTSFILE
echo ""


CMD="python -u ${bert_path}/run_pretraining.py \
     --use_hpu \
     --warmup_proportion=$WARMUP \
     --constant_proportion=$CONST \
     --resume_from_checkpoint \
     --do_train \
     --bert_model=bert-base-uncased \
     --config_file=$MODEL_CONFIG \
     --json-summary=$RESULTS_DIR/dllogger.json \
     --output_dir=$RESULTS_DIR/checkpoints \
     --seed=12439 \
     --optimizer=nvlamb \
     --use_lr_scheduler \
     --input_dir=$DATA_DIR \
     --max_seq_length $MAX_SEQ_LENGTH \
     --max_predictions_per_seq=20 \
     --max_steps=$MAX_STEPS \
     --num_steps_per_checkpoint=$NUM_STEPS_PER_CP \
     --learning_rate=$LR \
     --deepspeed \
     --deepspeed_config=$DS_CONFIG"


mkdir -p $RESULTS_DIR
deepspeed --no_local_rank \
          --no_python \
          /usr/bin/bash -c "$CMD" \
          2>&1 | tee $RESULTS_DIR/training.log
