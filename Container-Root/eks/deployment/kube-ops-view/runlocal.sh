#!/bin/bash

docker run -it --rm -p 8080:8080 -v ${HOME}/.kube/config:/root/.kube/config -e KUBECONFIG_CONTEXTS=<comma_separated_cluster_name_list> -e KUBECONFIG_PATH=/root/.kube/config  hjacobs/kube-ops-view

