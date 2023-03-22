#!/bin/bash

kubectl delete -f ./imagenet-cpu.yaml

kubectl delete pod $(kubectl get pod | grep etcd | cut -n ' ' -f 1)

