#!/bin/bash

helm uninstall -n stable-diffusion $(helm list -n stable-diffusion | grep stable-diffusion | awk '{print $1}')

