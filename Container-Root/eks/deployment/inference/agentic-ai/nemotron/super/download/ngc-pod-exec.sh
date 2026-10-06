#!/bin/bash

echo ""
echo "Opening do-ngc shell ..."

export CMD="kubectl exec -it do-ngc -- bash"
if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "${CMD}"
