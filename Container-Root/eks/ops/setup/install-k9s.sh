#!/bin/bash

export K9S_VERSION="v0.31.7"

echo ""
echo "Installing k9s version ${K9_VERSION} ..."


ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
  GOARCH=arm64
else
  GOARCH=amd64
fi

# Install kubectl
# Reference: https://k9scli.io/topics/install/
URL=https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_linux_${GOARCH}.deb
echo "$URL"
pushd /tmp
curl -Lo k9s.deb $URL
sudo apt install ./k9s.deb
rm -rf ./k9s.deb
k9s version
popd

