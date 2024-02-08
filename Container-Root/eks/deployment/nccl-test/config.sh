#!/bin/bash

CMD="vi .env"

if [ "$VERBOSE" == true ]; then
	echo ""
	echo "$CMD"
	echo ""
fi

eval "$CMD"

