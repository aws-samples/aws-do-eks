#!/bin/bash

FILESIZE=100G

if [ ! "$1" == "" ]; then
	FILESIZE=$1
fi

pattern="^[0-9]{1,10}[a-zA-Z]{1,3}$"

echo ""
if [[ "$FILESIZE" =~ $pattern ]]; then
    echo "Creating file /cratch/largefile.dmp of size $FILESIZE"
    kubectl exec -it emptydir-pod -- bash -c "fallocate -l $FILESIZE /scratch/largefile.dmp; ls -alh /scratch"
else
    echo "Aborting file creation ..."
    echo "Usage: $0 [FILESIZE]"
    echo "Please specify FILESIZE as sequence of 1 to 10 digits followed by 1 to 3 characters, example: 100G"
fi
echo ""

