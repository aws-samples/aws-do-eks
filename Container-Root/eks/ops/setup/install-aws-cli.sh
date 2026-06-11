#!/bin/bash

echo ""
echo "Installing AWS CLI ..."

ARCH=$(uname -m)
OS=$(uname -s)
OS_LOWER=$(echo $OS | tr '[:upper:]' '[:lower:]')
PLATFORM=${OS_LOWER}-${ARCH}
# Install aws cli
if [ "$OS" == "Darwin" ]; then
	echo "Installing AWS CLI on Mac ..."
	URL="https://awscli.amazonaws.com/AWSCLIV2.pkg"
	echo "${URL}"
	curl "${URL}" -o "AWSCLIV2.pkg"
	sudo installer -pkg AWSCLIV2.pkg -target /
else
	echo "Installing AWS CLI on Linux ..."
	URL=https://awscli.amazonaws.com/awscli-exe-${PLATFORM}.zip
	echo "$URL"
	curl "$URL" -o "awscliv2.zip"
	unzip awscliv2.zip
	./aws/install
	sudo cp -f /usr/local/bin/aws /bin/aws
	rm -rf ./aws
	rm -f awscliv2.zip
fi
aws --version

