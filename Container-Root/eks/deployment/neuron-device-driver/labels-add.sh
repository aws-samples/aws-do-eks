#!/bin/bash

kubectl label nodes $(kubectl get nodes -L node.kubernetes.io/instance-type | grep inf2 | cut -d ' ' -f 1 ) processor=inf2 
