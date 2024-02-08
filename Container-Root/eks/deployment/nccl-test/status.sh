#!/bin/bash

echo ""
echo "Status:"
echo ""

CMD1="kubectl get mpijobs"
CMD2="kubectl get pods"

if [ "$VERBOSE" == "true" ]; then
	echo ""
	echo "$CMD1"
	echo "$CMD2"
	echo ""
fi

if [ ! "$DRY_RUN" == "true" ]; then
	eval "$CMD1"
	eval "$CMD2"
fi

