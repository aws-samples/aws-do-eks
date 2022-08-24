#!/bin/bash

kubectl logs -f $(kubectl get pods | grep deepspeed-bert-launcher | cut -d ' ' -f 1)

