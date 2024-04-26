#!/bin/bash

CMD="kubectl -n default get daemonset | grep -E 'AVAILABLE|efaburn'"
if [ ! "$VERBOSE" == "false" ]; then
	echo "$CMD"
fi
eval "$CMD"

CMD="kubectl -n default get pods -o wide | grep -E 'STATUS|efaburn'"
if [ ! "$VERBOSE" == "false" ]; then
	echo "$CMD"
fi
eval "$CMD"

