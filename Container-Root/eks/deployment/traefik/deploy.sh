#!/bin/bash

kubectl create namespace traefik

helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install --namespace=traefik --values=./custom-values.yaml traefik traefik/traefik --version=26.0.0

