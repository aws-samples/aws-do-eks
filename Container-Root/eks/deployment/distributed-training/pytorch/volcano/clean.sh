#!/bin/bash

kubectl delete vcjob $(kubectl get vcjob | cut -d ' ' -f 1)

