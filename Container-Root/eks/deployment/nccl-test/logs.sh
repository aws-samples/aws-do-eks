#!/bin/bash

echo ""
echo "Logs:"

CMD="kubectl logs -f \$(kubectl get pods | grep launcher | cut -d ' ' -f 1)"

if [ "$VERBOSE" == "true" ]; then
	echo ""
	echo "$CMD"
	echo ""
fi

if [ ! "$DRY_RUN" == "true" ]; then
	eval "$CMD"
fi

