#!/bin/bash

CMD="kubetail efaburn"

if [ ! "$VERBOSE" == "false" ]; then
	echo "$CMD"
fi
eval "$CMD"

