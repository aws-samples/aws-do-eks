#!/bin/sh

if [ -d /etc/apt ]; then
        [ -n "$http_proxy" ] && echo "Acquire::http::proxy \"${http_proxy}\";" > /etc/apt/apt.conf; \
        [ -n "$https_proxy" ] && echo "Acquire::https::proxy \"${https_proxy}\";" >> /etc/apt/apt.conf; \
        [ -f /etc/apt/apt.conf ] && cat /etc/apt/apt.conf
        apt-get update -y
fi


export PYTHONUNBUFFERED=TRUE
export PYTHONDONTWRITEBYTECODE=TRUE

echo -e '[neuron]\nname=Neuron YUM Repository\nbaseurl=https://yum.repos.neuron.amazonaws.com\nenabled=1\nmetadata_expire=0\n' >> /etc/yum.repos.d/neuron.repo
rpm --import https://yum.repos.neuron.amazonaws.com/GPG-PUB-KEY-AMAZON-AWS-NEURON.PUB
amazon-linux-extras install -y python3.8

yum update -y && yum upgrade -y && \
    yum install -y git tar gzip ca-certificates procps net-tools which vim wget libgomp htop jq bind-utils bc pciutils && \
    yum install -y gcc-c++ && \
    yum install -y jq java-11-amazon-corretto-headless  # for torchserve

yum install -y aws-neuronx-collectives-${NEURONX_COLLECTIVES_LIB_VERSION} && \
    yum install -y aws-neuronx-runtime-lib-${NEURONX_RUNTIME_LIB_VERSION} && \
    yum install -y aws-neuronx-tools-${NEURONX_TOOLS_VERSION}

#fix for incorrect Python version configured by default in the base image
rm -f /usr/bin/python
ln -s /usr/bin/python3.8 /usr/bin/python3
ln -s /usr/bin/python3 /usr/bin/python

update-alternatives --install /usr/bin/pip pip /usr/bin/pip3.8 1

pip3.8 install --extra-index-url https://pip.repos.neuron.amazonaws.com \
    neuronx-cc==$NEURONX_CC_VERSION \
    torch-neuronx==$NEURONX_FRAMEWORK_VERSION \
    transformers-neuronx==$NEURONX_TRANSFORMERS_VERSION 

pip3.8 install "protobuf<4" \
    && pip3.8 install torchserve==${TORCHSERVE_VERSION} \
    && pip3.8 install torch-model-archiver==${TORCHSERVE_VERSION} \
    && pip3.8 install --no-deps --no-cache-dir -U torchvision==0.14.* captum==0.6.0 configparser

echo "alias ll='ls -alh --color=auto'" >> /root/.bashrc 

# SBOM
./setup-sbom-utils.sh
./sbom.sh

