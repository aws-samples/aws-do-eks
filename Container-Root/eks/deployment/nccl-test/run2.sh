#!/bin/bash

. .env

TEST_NAME=$1
if [ "$1" == "" ]; then
	TEST_NAME="all-reduce-pair"
fi


NODES=($(kubectl get nodes -L node.kubernetes.io/instance-type | grep ${INSTANCE_TYPE} | grep Ready | grep -v Not | cut -d ' ' -f 1))
NUM_NODES=${#NODES[@]}

echo ""
echo "Found $NUM_NODES 'Ready' nodes. Generating MPI jobs for test $TEST_NAME  ..."
echo ""

mkdir -p $TEST_NAME

i=0
p=1

while [ $i -lt $NUM_NODES ]; do
	
	export MPI_PAIR_JOB_NAME=${TEST_NAME}-$p
	export HOSTNAME_1=${NODES[$i]}
	
	i=$((i+1))
	if [ $i -lt $NUM_NODES ]; then
		export HOSTNAME_2=${NODES[$i]}
	else
		export HOSTNAME_2=${NODES[0]}
	fi

	cat ./${TEST_NAME}.yaml-template | envsubst > ./$TEST_NAME/${MPI_PAIR_JOB_NAME}.yaml
	
	i=$((i+1))
	p=$((p+1))
done

CMD="kubectl apply -f ./${TEST_NAME}"

if [ "$VERBOSE" == "true" ]; then
	echo ""
	echo "$CMD"
	echo ""
fi

if [ ! "$DRY_RUN" == "true" ]; then
	eval "$CMD"
fi

