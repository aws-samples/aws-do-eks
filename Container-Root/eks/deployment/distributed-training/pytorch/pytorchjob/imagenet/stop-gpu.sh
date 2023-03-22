#!/bin/bash

kubectl delete -f ./imagenet-gpu.yaml

kubectl delete pod $(kubectl get pod | grep etd | cut -d ' ' -f 1)

