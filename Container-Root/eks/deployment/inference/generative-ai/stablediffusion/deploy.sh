#!/bin/bash

# Reference: https://github.com/amithkk/stable-diffusion-k8s

helm repo add amithkk-sd https://amithkk.github.io/stable-diffusion-k8s

helm repo update

#helm install --generate-name amithkk-sd/stable-diffusion -f values.yaml
helm install stable-diffusion -n stable-diffusion --create-namespace  amithkk-sd/stable-diffusion -f values.yaml


