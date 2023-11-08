#!/bin/bash

ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
  GOARCH=arm64
else
  GOARCH=amd64
fi
PLATFORM=$(uname -s)_$GOARCH

# Install eksctl

curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_${PLATFORM}.tar.gz" | tar xz -C /tmp

#curl --location "https://github.com/weaveworks/eksctl/releases/download/v0.160.0-rc.0/eksctl_${PLATFORM}.tar.gz" | tar xz -C /tmp

mv /tmp/eksctl /usr/local/bin

eksctl version

