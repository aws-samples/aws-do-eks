#!/bin/bash


###################################################
## Install Debian license manager 
echo "Installing Debian License Manager ...."
cd /opt
wget https://github.com/daald/dpkg-licenses/archive/master.zip -O master.zip; unzip master.zip; rm master.zip

