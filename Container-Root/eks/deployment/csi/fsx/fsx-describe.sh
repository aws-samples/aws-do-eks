#!/bin/bash

echo ""
echo "Describing FSxL volumes ..."

CMD="aws fsx describe-file-systems"

if [ ! "$1" == "" ]; then
	VOL_ID=$1
	CMD="${CMD} --file-system-id ${VOL_ID}"
fi
if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "${CMD}"

