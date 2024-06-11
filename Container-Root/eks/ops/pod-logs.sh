#!/bin/bash

kubectl logs -f $(kubectl get pods | grep $1 | head -n 1 | cut -d ' ' -f 1)

