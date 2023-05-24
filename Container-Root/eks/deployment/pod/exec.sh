#!/bin/bash

if [ "$1" == "" ]; then
	CMD="sh"
else
	CMD="$@"
fi


kubectl exec -it pod -- "$CMD"

