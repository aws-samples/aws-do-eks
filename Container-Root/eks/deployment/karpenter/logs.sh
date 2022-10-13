#!/bin/bash

kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter -c controller

