#!/bin/bash

# Configure Linux for Neuron repository updates
sudo tee /etc/yum.repos.d/neuron.repo > /dev/null <<EOF
[neuron]
name=Neuron YUM Repository
baseurl=https://yum.repos.neuron.amazonaws.com
enabled=1
metadata_expire=0
EOF
sudo rpm --import https://yum.repos.neuron.amazonaws.com/GPG-PUB-KEY-AMAZON-AWS-NEURON.PUB

# Update OS packages 
sudo yum update -y

# Install OS headers 
sudo yum install kernel-devel-$(uname -r) kernel-headers-$(uname -r) -y

# Install git 
sudo yum install git -y

# install Neuron Driver
sudo yum install aws-neuronx-dkms-2.* -y

# Install Neuron Runtime 
sudo yum install aws-neuronx-collectives-2.* -y
sudo yum install aws-neuronx-runtime-lib-2.* -y

# Install Neuron Tools 
sudo yum install aws-neuronx-tools-2.* -y

# Add PATH
echo "PATH=/opt/aws/neuron/bin:$PATH" >> /etc/bashrc

