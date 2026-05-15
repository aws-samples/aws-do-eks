#!/bin/bash
set -e

# check to see if kubetail is installed
if command -v kubetail >/dev/null 2>&1; then
  echo "kubetail is already installed at $(command -v kubetail)"
  exit 0
fi

# install kubetail if not already installed
curl -o /tmp/kubetail https://raw.githubusercontent.com/johanhaleby/kubetail/master/kubetail
chmod +x /tmp/kubetail
mv /tmp/kubetail /usr/local/bin/kubetail