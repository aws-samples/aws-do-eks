#!/bin/bash

kubectl delete -f ./hyperthreading-off-daemonset.yaml

kubectl apply -f ./hyperthreading-on-daemonset.yaml

