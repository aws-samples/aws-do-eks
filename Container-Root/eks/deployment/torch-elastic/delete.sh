#!/bin/bash

kubectl delete -f config/samples/etcd.yaml

kubectl delete -k config/default
