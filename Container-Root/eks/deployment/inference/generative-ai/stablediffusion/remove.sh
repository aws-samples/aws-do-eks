#!/bin/bash

kubectl -n stable-diffusion delete -f ./hpa.yaml

kubectl -n stable-diffusion delete -f ./ingress.yaml

kubectl -n stable-diffusion delete -f ./deployment.yaml

sleep 2

helm uninstall -n stable-diffusion $(helm list -n stable-diffusion | grep stable-diffusion | awk '{print $1}')

