#!/bin/bash

PORT=9000
if [ ! "$1" == "" ]; then
	PORT="$1"
fi

echo ""
echo "Exposing traefik port ${PORT} on local port 8080 ..."

kubectl -n traefik port-forward $(kubectl -n traefik get pods --selector "app.kubernetes.io/name=traefik" --output=name) 8080:${PORT} &

echo ""
echo "If you are in a Cloud9 environment, the Traefik service is available via the following URL:"
REGION=$(hostname | cut -d '.' -f 2)
echo REGION=$REGION
echo https://${C9_PID}.vfs.cloud9.${REGION}.amazonaws.com/dashboard/

echo ""
echo "If you are port-forwarding from a local machine, the Grafana dashboard is available via the following URL:"
echo "http://localhost:8080"

