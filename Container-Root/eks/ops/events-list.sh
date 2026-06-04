#!/bin/bash

# By default events are not sorted, with this sort, the latest events are at the bottom of the list
# optionally speciry -o wide to get more information

kubectl get events --sort-by='.metadata.creationTimestamp' "$@"

