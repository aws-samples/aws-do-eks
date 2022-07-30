#!/bin/bash

kubectl delete -f etcd.yaml

kubectl delete -k config/default
