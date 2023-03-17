#!/bin/bash

kubectl delete pod $(kubectl get pod | grep main | cut -d ' ' -f 1)

