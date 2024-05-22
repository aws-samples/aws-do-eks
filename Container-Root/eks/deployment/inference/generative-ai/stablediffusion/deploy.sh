#!/bin/bash

source .env

# Reference: https://github.com/amithkk/stable-diffusion-k8s

helm repo add amithkk-sd https://amithkk.github.io/stable-diffusion-k8s

helm repo update

#helm install --generate-name amithkk-sd/stable-diffusion -f values.yaml
helm install stable-diffusion -n stable-diffusion --create-namespace  amithkk-sd/stable-diffusion -f values.yaml

sleep 2 

kubectl -n stable-diffusion delete statefulset stable-diffusion

kubectl -n stable-diffusion apply -f ./deployment.yaml

cat ./ingress.yaml-template | envsubst > ./ingress.yaml

kubectl -n stable-diffusion apply -f ./ingress.yaml

kubectl -n stable-diffusion apply -f ./hpa.yaml

