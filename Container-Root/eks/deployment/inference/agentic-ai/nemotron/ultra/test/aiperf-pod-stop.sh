#!/bin/bash

# Ref: https://github.com/iankoulski/do-aiperf

echo "Removing do-aiperf pod ..."

export CMD="kubectl delete pod do-aiperf"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi

eval "${CMD}"
