#!/bin/bash

watch kubectl get nodes -L node.kubernetes.io/instance-type "$@"
