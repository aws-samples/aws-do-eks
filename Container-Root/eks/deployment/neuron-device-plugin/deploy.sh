#!/bin/bash

kubectl apply -f https://raw.githubusercontent.com/aws/aws-neuron-sdk/master/src/k8/k8s-neuron-device-plugin-rbac.yml
kubectl apply -f https://raw.githubusercontent.com/aws/aws-neuron-sdk/master/src/k8/k8s-neuron-device-plugin.yml


