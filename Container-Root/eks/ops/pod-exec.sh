#!/bin/bash

kubectl exec -it $(kubectl get pods | grep $1 | cut -d ' ' -f 1) -- bash

