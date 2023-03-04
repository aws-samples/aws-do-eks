#!/bin/bash

# Reference: https://artifacthub.io/packages/helm

kubens monitoring

helm uninstall prometheus-cloudwatch-exporter 

