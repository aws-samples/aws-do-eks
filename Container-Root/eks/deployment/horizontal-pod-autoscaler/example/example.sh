#!/bin/bash

# Prerequisites
#../../deploy-metrics-server.sh

# Simple example
kubectl apply -f ./php-apache.yaml

kubectl -n hpa-example autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10

kubectl -n hpa-example get hpa

#kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"
kubectl -n hpa-example run load-generator --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"

sleep 60

kubectl -n hpa-example get hpa

kubectl -n hpa-example get deployment php-apache

kubectl -n hpa-example delete pod load-generator

kubectl -n hpa-example get hpa.v2beta2.autoscaling -o yaml > /tmp/hpa-v2.yaml

kubectl -n hpa-example delete hpa php-apache
