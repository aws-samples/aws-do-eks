#!/bin/bash

kubectl apply -k config/default

kubectl -n elastic-job get pods

kubectl apply -f etcd.yaml

