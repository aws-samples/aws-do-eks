#!/bin/bash

kubectl delete vcjob $(kubectl get vcjob | grep rain | cut -d ' ' -f 1)

