#!/bin/bash

echo ""
echo "Removing do-ngc pod ..."

export CMD="kubectl delete pod do-ngc --force --grace-period=0"
if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "${CMD}"
