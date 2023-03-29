#!/bin/bash

#for j in $(torchx list -s kubernetes | grep imagenet | grep RUNNING | cut -d ' ' -f 1); do echo stopping $j; torchx cancel $j; done 

kubectl delete vcjob $(kubectl get vcjob | grep imagenet | cut -d ' ' -f 1)

