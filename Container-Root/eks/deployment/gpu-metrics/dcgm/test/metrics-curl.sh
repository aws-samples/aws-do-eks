#!/bin/bash

kubectl exec -it metrics-curl -- sh -c "curl -sL http://dcgm-exporter.kube-system.svc.cluster.local:9400/metrics | grep -v '#'"

