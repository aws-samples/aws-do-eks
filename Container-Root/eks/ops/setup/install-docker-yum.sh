#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

if [ -f /usr/bin/yum ]; then
    echo ""
    echo "Installing Docker ..."
    #yum update
    #sudo yum install docker -y
    
    while true; do
	sudo dnf update --assumeyes && break
	sleep 5
    done

    while true; do
        sudo dnf install --assumeyes docker && break
	sleep 5
    done
    
    usermod -a -G docker ec2-user
    id ec2-user
    newgrp docker
    systemctl enable docker.service
    systemctl enable docker
    sleep 5
    systemctl start docker.service
    systemctl start docker
    echo ""
    echo "Done installing Docker."
    echo ""
else
    echo "/usr/bin/yum does not exist"
    echo "Cannot install Docker cli with this script"
    echo "Please refer to https://docs.docker.com/engine/install"
fi

