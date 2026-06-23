#!/bin/bash

echo ""
echo "Opening do-hf shell ..."

export CMD="kubectl exec -it do-hf -- bash"
if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "${CMD}"
