#!/bin/bash

. .env

CMD="vi .env"
if [ ! "$VERBOSE" == "false" ]; then
	echo "$CMD"
fi
eval "$CMD"

