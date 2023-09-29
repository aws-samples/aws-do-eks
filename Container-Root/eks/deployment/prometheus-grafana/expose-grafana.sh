#!/bin/bash

kubectl port-forward -n grafana svc/grafana 8080:80 --address 0.0.0.0 &

echo ""
echo "If you are in a Cloud9 environment, the Grafana dashboard is available via the following URL:"
REGION=$(hostname | cut -d '.' -f 2)
echo REGION=$REGION
echo https://${C9_PID}.vfs.cloud9.${REGION}.amazonaws.com/login

echo ""
echo "If you are port-forwarding from a local machine, the Grafana dashboard is available via the following URL:"
echo "http://localhost:8080"

