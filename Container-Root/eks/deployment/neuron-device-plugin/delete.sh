#!/bin/bash

kubectl delete -f https://raw.githubusercontent.com/aws/aws-neuron-sdk/master/src/k8/k8s-neuron-device-plugin.yml
kubectl delete -f https://raw.githubusercontent.com/aws/aws-neuron-sdk/master/src/k8/k8s-neuron-device-plugin-rbac.yml


