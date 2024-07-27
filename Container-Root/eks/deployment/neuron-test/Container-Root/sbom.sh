#!/bin/sh

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: Apache-2.0                                #
###################################################################### 

# Software bill of materials (SBOM) generation script

echo ""
echo "Generating SBOM.txt"

if [ -d /etc/apt ]; then
    echo "Using Debian License Manager (dpkg) ..."
    cd /opt/dpkg-licenses-master
    ./dpkg-licenses > /SBOM.txt
else
    echo "Using Red Hat Package Manager (rpm) ..."
    rpm -qa --queryformat "%{NAME}-%{VERSION}: %{LICENSE}\n" > /SBOM.txt
fi

if [ -d /wd ]; then
    echo "" >> /SBOM.txt
    echo "An up-to-date Software Bill of Materials is also available in the container at /SBOM.txt" >> /SBOM.txt
    echo "" >> /SBOM.txt
    cp -f /SBOM.txt /wd/SBOM.txt
fi

echo ""
echo "Done"

