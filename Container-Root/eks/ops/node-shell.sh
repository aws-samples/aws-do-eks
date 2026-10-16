#!/bin/bash

if [ "$1" == "" ]; then
	echo ""
	echo "Please specify node name or unique part of a node name as argument"
else
	full_node_name=$(kubectl get nodes | grep $1 | head -n 1 | cut -d ' ' -f 1)
	if [ -z "$full_node_name" ]; then
		echo "ERROR: no node matches '$1'" >&2
		exit 1
	fi
	# Detect OS — Bottlerocket has no usable interactive shell on the host
	os_image=$(kubectl get node "$full_node_name" -o jsonpath='{.status.nodeInfo.osImage}')
	if echo "$os_image" | grep -qi bottlerocket; then
		# Use container's shell; host root is mounted at /host
		kubectl node-shell --no-mount -x "$full_node_name"
	else
		# Regular Linux — use bash directly on the host
		kubectl node-shell "$full_node_name" -- bash -l
	fi
fi
