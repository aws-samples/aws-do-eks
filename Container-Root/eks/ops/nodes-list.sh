#!/bin/bash

kubectl get nodes -L node.kubernetes.io/instance-type "$@"

