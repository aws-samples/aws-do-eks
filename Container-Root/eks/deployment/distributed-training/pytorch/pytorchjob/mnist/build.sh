#!/bin/bash

function usage(){
	echo ""
	echo "Usage: ${0} [suffix]"
	echo "suffix - Dockerfile suffix (e.g. mpi)"
	echo ""
}

source .env

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
	usage
else
	if [ "$1" == "" ]; then
		docker build -t ${REGISTRY}${IMAGE}:latest -f Dockerfile .
	else
		if [ -f "./Dockerfile-$1" ]; then
			docker build -t ${REGISTRY}${IMAGE}:$1 -f Dockerfile-$1 .
		else
			echo "Dockerfile-$1 not found"
		fi
	fi
fi

