#!/bin/bash

# This script installs Cloud9

# Install dev tools
if [ -d /etc/apt ]; then
  sudo apt-get update
  DEBIAN_FRONTEND=noninteractive sudo apt-get install -y build-essential
else
  sudo yum -y groupinstall "Development Tools"
fi

# Install nodejs
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.39.0/install.sh | bash
source ~/.nvm/nvm.sh
source ~/.bashrc
nvm install 16.15.1
if [ ! -f /usr/bin/node ]; then
 sudo ln -s /home/ubuntu/.nvm/versions/node/v16.15.1/bin/node /usr/bin/node
fi
node --version

# Install Cloud9
curl -L https://raw.githubusercontent.com/c9/install/master/install.sh | bash


