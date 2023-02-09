#!/bin/bash

kubectl delete -f ./hyperthreading-on-daemonset.yaml

kubectl apply -f ./hyperthreading-off-daemonset.yaml

