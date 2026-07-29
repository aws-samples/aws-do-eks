#!/bin/bash

set -e

# Ref: https://zellij.dev/documentation/installation.html

ZELLIJ_VERSION=v0.44.3

ARCH=$(uname -m)
ARCH_TAG=x86_64
if [ "$ARCH" == "arm64" ]; then
	ARCH_TAG=aarch64
elif [ "$ARCH" == "amd64" ]; then
	ARCH_TAG=x86_64
fi
 

OS=$(uname)
OS_TAG=unknown-linux
if [ "$OS" == "Darwin" ]; then
	OS_TAG=apple-darwin
fi


URL=https://github.com/zellij-org/zellij/releases/download/${ZELLIJ_VERSION}/zellij-${ARCH_TAG}-${OS_TAG}.tar.gz

echo "Installing Zellij ${ZELLIJ_VERSION} from ${URL} ..."

wget $URL -O /tmp/zellij.tar.gz

pushd /tmp
tar -xvf zellij.tar.gz
chmod +x zellij
mv /tmp/zellij /usr/local/bin
rm -rf /tmp/zellij.tar.gz
popd

