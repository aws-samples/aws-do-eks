#!/bin/bash

# Install Terraform
echo ""
echo "Installing Terraform ..."

which apt > /dev/null 2>&1
if [ "$?" == "0" ]; then
	# apt is available
	apt-get update && apt-get install -y gnupg software-properties-common
	gpg_file=/usr/share/keyrings/hashicorp-archive-keyring.gpg
	if [ -f $gpg_file ]; then
		rm -f $gpg_file
	fi
	wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee $gpg_file > /dev/null
	gpg --no-default-keyring --keyring $gpg_file --fingerprint
	#echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
	echo "deb [arch=$(dpkg --print-architecture) signed-by=${gpg_file}] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
	apt update
	apt install -y terraform
else
	# assume yum
	yum install -y yum-utils
	yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
	yum -y install terraform
fi

terraform --version

