#!/bin/bash

kubectl logs -f $(kubectl get pod | grep main | head -n 1 | cut -d ' ' -f 1)

