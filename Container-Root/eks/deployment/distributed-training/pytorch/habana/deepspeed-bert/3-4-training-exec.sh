#!/bin/bash

kubectl exec -it $(kubectl get pods | grep deepspeed-bert-launcher | cut -d ' ' -f 1) -- bash

