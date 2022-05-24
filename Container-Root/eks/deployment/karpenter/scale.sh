#!/bin/bash


if [ "$1" == "" ]; then
        echo ""
        echo "Please specify scale/number of pods to run as an argument"
        echo ""
else
        kubectl scale deployment inflate --replicas $1
fi

