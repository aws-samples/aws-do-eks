#!/bin/bash

# Install golang
# https://go.dev/doc/install

ARCH=$(uname -m)
if [ "${ARCH}" == "aarch64" ]; then ARCH=arm64; fi
curl -o go.tar.gz --location "https://go.dev/dl/go1.20.linux-${ARCH}.tar.gz"
rm -rf /usr/local/go && tar -C /usr/local -xzf go.tar.gz
rm -f ./go.tar.gz
echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.bashrc
ln -s /usr/local/go/bin/go /usr/local/bin/go
export PATH=$PATH:/usr/local/go/bin
go version

