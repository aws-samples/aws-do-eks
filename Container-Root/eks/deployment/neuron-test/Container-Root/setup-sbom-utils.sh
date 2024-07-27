#!/bin/bash


#####################################################
## Install Debian license manager if system is Debian

which dpkg 2>&1 1>/dev/null

if [ "$?" == "0" ]; then

    echo "Installing Debian License Manager ...."
    cd /opt
    wget https://github.com/daald/dpkg-licenses/archive/master.zip -O master.zip; unzip master.zip; rm master.zip
else
    echo "dpkg not available on system"
    echo "Skipping Debian License Manager installation ..."
fi

