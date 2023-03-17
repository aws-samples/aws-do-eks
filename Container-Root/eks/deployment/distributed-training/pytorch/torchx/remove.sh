#!/bin/bash

# Instructions available here: https://pytorch.org/torchx/latest/schedulers/kubernetes.html

pip uninstall -y torchx[kubernetes]

kubectl delete -f https://raw.githubusercontent.com/volcano-sh/volcano/release-1.7/installer/volcano-development.yaml

