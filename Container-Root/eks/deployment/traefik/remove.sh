#!/bin/bash

helm uninstall traefik

#kubectl delete -f ./manifests

kubectl delete namespace traefik

