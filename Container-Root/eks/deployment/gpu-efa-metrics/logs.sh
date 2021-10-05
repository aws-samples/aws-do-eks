#!/bin/bash

kubectl -n kube-system logs --selector app.kubernetes.io/name=gpu-efa-metrics --tail -1 -c installer

