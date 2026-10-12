#!/bin/bash

echo ""
echo "Removing do-hf pod ..."

export CMD="kubectl delete pod do-hf --force --grace-period=0"
if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "${CMD}"
