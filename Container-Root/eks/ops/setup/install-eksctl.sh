#!/bin/bash

curl --location "https://github.com/weaveworks/eksctl/releases/download/v0.106.0/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
mv /tmp/eksctl /usr/local/bin
eksctl version

