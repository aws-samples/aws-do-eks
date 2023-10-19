#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

if [ -f /usr/bin/yum ]; then
    yum update
    yum install docker -y
    usermod -a -G docker ec2-user
    id ec2-user
    newgrp docker
    systemctl enable docker
    sleep 2
    systemctl start docker
else
    echo "/usr/bin/yum does not exist"
    echo "Cannot install Docker cli with this script"
    echo "Please refer to https://docs.docker.com/engine/install"
fi

