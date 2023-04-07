#!/bin/bash

echo ""
ps -aef | grep port-forward | grep traefik
PORT_FORWARD_PID=$(ps -aef | grep port-forward | grep traefik | awk '{print $2}')
if [ "$PORT_FORWARD_PID" == "" ]; then
	echo "Port forwarding is not active"
else
	echo "Removing PID $PORT_FORWARD_PID ..."
	kill -9 ${PORT_FORWARD_PID}
fi

