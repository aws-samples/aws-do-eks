#!/bin/bash

# Ref: https://zellij.dev/documentation/installation.html


wget https://github.com/zellij-org/zellij/releases/download/v0.44.1/zellij-aarch64-unknown-linux-musl.tar.gz -O /tmp/zellij.tar.gz

pushd /tmp
tar -xvf zellij.tar.gz
chmod +x zellij
mv /tmp/zellij /usr/bin
rm -rf /tmp/zellij.tar.gz
popd

