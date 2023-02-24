#!/bin/bash

kubectl -n stable-diffusion port-forward svc/stable-diffusion 8080:80 &

