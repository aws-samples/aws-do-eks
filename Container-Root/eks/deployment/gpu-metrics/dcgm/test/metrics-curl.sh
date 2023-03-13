#!/bin/bash

kubectl -n kube-system exec -it metrics-curl -- sh -c "curl -sL http://dcgm-exporter.kube-system.svc.cluster.local:9400/metrics"

