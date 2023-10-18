#!/bin/bash

ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
	GOARCH=arm64
else
	GOARCH=amd64
fi
PLATFORM=$(uname -s)-$GOARCH

curl -L https://github.com/a8m/envsubst/releases/download/v1.2.0/envsubst-${PLATFORM} -o envsubst
chmod +x envsubst
sudo mv envsubst /usr/local/bin

