#!/bin/bash


# curl https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.44.0/deploy/static/provider/aws/deploy.yaml -o nginx-ingress-controller.yaml

kubectl apply -f ./nginx-ingress-controller.yaml

