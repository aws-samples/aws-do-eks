#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

if [ -f /usr/bin/yum ]; then
    sudo yum update
    sudo yum install docker -y
    sudo usermod -a -G docker ec2-user
    id ec2-user
    sudo newgrp docker
    sudo systemctl enable docker
    sleep 2
    sudo systemctl start docker
else
    echo "/usr/bin/yum does not exist"
    echo "Cannot install Docker cli with this script"
    echo "Please refer to https://docs.docker.com/engine/install"
fi

