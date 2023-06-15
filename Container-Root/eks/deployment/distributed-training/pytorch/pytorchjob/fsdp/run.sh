#!/bin/bash

./generate.sh

kubectl apply -f ./fsdp.yaml

