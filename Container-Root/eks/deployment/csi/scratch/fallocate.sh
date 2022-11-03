#!/bin/bash

FILESIZE=100G

if [ ! "$1" == "" ]; then
	FILESIZE=$1
fi

kubectl exec -it emptydir-pod -- bash -c "fallocate -l $FILESIZE /scratch/largefile.dmp; ls -alh /scratch"

