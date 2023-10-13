#!/bin/bash

kubectl -n kube-system logs --selector app.kubernetes.io/name=neuron2-device-driver --tail -1 -c installer

