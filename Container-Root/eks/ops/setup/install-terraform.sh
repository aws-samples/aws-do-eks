#!/bin/bash

# Install Terraform
echo ""
echo "Installing Terraform ..."

which apt > /dev/null 2>&1
if [ "$?" == "0" ]; then
	# apt is available
	gpg_file=/usr/share/keyrings/hashicorp-archive-keyring.gpg
	if [ -f $gpg_file ]; then
		rm -f $gpg_file
	fi
	wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o $gpg_file
	echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
	apt update
	apt install -y terraform
else
	# assume yum
	yum install -y yum-utils
	yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
	yum -y install terraform
fi

terraform --version

