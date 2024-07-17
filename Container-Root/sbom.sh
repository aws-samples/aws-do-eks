#!/bin/sh

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: Apache-2.0                                #
###################################################################### 

# Software bill of material generation script
echo ""
echo "Generating /SBOM.txt"

cd /opt/dpkg-licenses-master
./dpkg-licenses > /SBOM.txt

if [ -d /wd ]; then
    echo "" >> /SBOM.txt
    echo "An up-to-date Software Bill of Materials is available in the container at /SBOM.txt" >> /SBOM.txt
    echo "" >> /SBOM.txt
    cp -f /SBOM.txt /wd/SBOM.txt
fi

echo ""
echo "Done"

