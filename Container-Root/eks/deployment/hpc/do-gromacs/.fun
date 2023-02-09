#!/bin/bash

# Helper functions
## Detect current operating system
function os
{
        UNAME=$(uname -a)
        if [ $(echo $UNAME | awk '{print $1}') == "Darwin" ]; then
                export OPERATING_SYSTEM="MacOS"
        elif [ $(echo $UNAME | awk '{print $1}') == "Linux" ]; then
                export OPERATING_SYSTEM="Linux"
        elif [ ${UNAME:0:5} == "MINGW" ]; then
                export OPERATING_SYSTEM="Windows"
                export MSYS_NO_PATHCONV=1 # turn off path conversion
        else
                export OPERATING_SYSTEM="Other"
        fi
}
## End os function
os

## Determine current host IP address
function hostip
{
	case "${OPERATING_SYSTEM}" in
        "Linux")
                export HOST_IP=$(hostname -I | tr " " "\n" | head -1) # Linux
                ;;
        "MacOS")
                export HOST_IP=$(ifconfig | grep -v 127.0.0.1 | grep -v inet6 | grep inet | head -n 1 | awk '{print $2}') # Mac OS
                ;;
        "Windows")
                export HOST_IP=$( ((ipconfig | grep IPv4 | grep 10.187 | tail -1) && (ipconfig | grep IPv4 | grep 3. | head -1)) | tail -1 | awk '{print $14}' ) # Git bash
                ;;
        *)
                export HOST_IP=$(hostname)
                ;;
	esac
}
## End hostip function 
hostip

## generate_kubernetes_manifests function
function generate_kubernetes_manifests
{
        echo "Generating Kubernetes manifests ..."
        if [ -d "to/kubernetes/app" ]; then
		rm -f to/kubernetes/app/*.yaml
	else
                mkdir -p "to/kubernetes/app"
        fi
        CMD="BASE_PATH=$(pwd); cd to/kubernetes/template; for f in *.yaml; do cat \$f | envsubst > \${BASE_PATH}/to/kubernetes/app/\$f; done; cd \${BASE_PATH}"
        if [ "${VERBOSE}" == "true" ]; then
                echo "${CMD}"
        fi
        eval "${CMD}"
}
## End generate_kubernetes_manifests function
