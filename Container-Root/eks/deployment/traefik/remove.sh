#!/bin/bash

helm uninstall traefik

kubectl delete namespace traefik

