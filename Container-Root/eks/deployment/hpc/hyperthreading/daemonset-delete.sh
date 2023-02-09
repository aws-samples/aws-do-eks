#!/bin/bash

kubectl delete -f ./hyperthreading-off-daemonset.yaml

kubectl delete -f ./hyperthreading-on-daemonset.yaml

