#!/bin/bash

# Install python2.7 on Ubuntu
echo ""
echo "Installing Python2.7 ..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y python2.7
update-alternatives --install /usr/bin/python python /usr/bin/python2.7 1
python --version

# Install pip
echo ""
echo "Installing pip ..."
curl https://bootstrap.pypa.io/pip/2.7/get-pip.py -o get-pip.py; python get-pip.py; rm -f get-pip.py
pip --version
