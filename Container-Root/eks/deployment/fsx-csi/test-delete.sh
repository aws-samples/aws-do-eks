#!/bin/bash

kubectl delete -f ./example-pod.yaml

kubectl delete -f ./example-pvc-static.yaml

kubectl delete -f ./example-pv-static.yaml

