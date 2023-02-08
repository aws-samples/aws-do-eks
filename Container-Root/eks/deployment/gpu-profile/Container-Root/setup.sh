#!/bin/sh

if [ -d /etc/apt ]; then
        [ -n "$http_proxy" ] && echo "Acquire::http::proxy \"${http_proxy}\";" > /etc/apt/apt.conf; \
        [ -n "$https_proxy" ] && echo "Acquire::https::proxy \"${https_proxy}\";" >> /etc/apt/apt.conf; \
        [ -f /etc/apt/apt.conf ] && cat /etc/apt/apt.conf
fi


# NVIDIA Nsight Systems 2023.1.1
apt-get update -y && \
     DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
         apt-transport-https \
         ca-certificates \
         gnupg \
         wget && \
     rm -rf /var/lib/apt/lists/*
wget -qO - https://developer.download.nvidia.com/devtools/repos/ubuntu2004/amd64/nvidia.pub | apt-key add - && \
     echo "deb https://developer.download.nvidia.com/devtools/repos/ubuntu2004/amd64/ /" >> /etc/apt/sources.list.d/nsight.list && \
     apt-get update -y && \
     DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
         nsight-systems-2023.1.1 && \
     rm -rf /var/lib/apt/lists/*

ln -s -f /opt/nvidia/nsight-systems/2023.1.1/bin/nsys /usr/local/cuda/bin/nsys

# Distributed training example
python -m pip install git+https://github.com/huggingface/transformers 
python -m pip install datasets evaluate

curl -L -o /run_clm.py https://raw.githubusercontent.com/huggingface/transformers/main/examples/pytorch/language-modeling/run_clm.py

export INSTALL_MPI=${INSTALL_MPI:-"true"}
export INSTALL_EFA=${INSTALL_EFA:-"false"}
export INSTALL_TESTS=${INSTALL_TESTS:-"false"}
echo ""
echo "INSTALL_MPI=$INSTALL_MPI"
echo "INSTALL_EFA=$INSTALL_EFA"
echo "INSTALL_TESTS=$INSTALL_TESTS"
echo ""

if [ "$INSTALL_MPI" == "true" ]; then
  # SSH
  apt-get update && apt-get install -y openssh-client openssh-server
  mkdir -p /var/run/sshd
  sed -i 's/[ #]\(.*StrictHostKeyChecking \).*/ \1no/g' /etc/ssh/ssh_config && \
    echo "    UserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config && \
    sed -i 's/#\(StrictModes \).*/\1no/g' /etc/ssh/sshd_config
  
  # Open MPI
  mkdir -p /tmp/openmpi && pushd /tmp/openmpi
  apt-get update && apt-get install build-essential autoconf gdb automake cmake
  wget https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-4.1.4.tar.gz 
  gunzip -c openmpi-4.1.4.tar.gz | tar xf -

  if [ "$INSTALL_EFA" == "true" ]; then
    # EFA
    EFA_INSTALLER_VERSION=latest
    AWS_OFI_NCCL_VERSION=aws
    curl -O https://efa-installer.amazonaws.com/aws-efa-installer-${EFA_INSTALLER_VERSION}.tar.gz \
      && tar -xf ./aws-efa-installer-${EFA_INSTALLER_VERSION}.tar.gz \
      && pushd aws-efa-installer \
      && ./efa_installer.sh -y -g -d --skip-kmod --skip-limit-conf --no-verify \
      && popd \
      && rm -rf ./aws-efa-installer*

    # NCCL
    NCCL_REPO=koyongse
    NCCL_VERSION=dynamic-buffer-depth

    git clone https://github.com/${NCCL_REPO}/nccl /opt/nccl \
      && pushd /opt/nccl \
      && git checkout dynamic-buffer-depth \
      && make -j src.build CUDA_HOME=/usr/local/cuda \
      NVCC_GENCODE="-gencode=arch=compute_86,code=sm_86 -gencode=arch=compute_80,code=sm_80 -gencode=arch=compute_75,code=sm_75 -gencode=arch=compute_70,code=sm_70 -gencode=arch=compute_60,code=sm_60" \
      && popd

    ## AWS-OFI-NCCL plugin
    export OPAL_PREFIX="" \
      && git clone https://github.com/aws/aws-ofi-nccl.git /opt/aws-ofi-nccl \
      && pushd /opt/aws-ofi-nccl \
      && env \
      && git checkout ${AWS_OFI_NCCL_VERSION} \
      && ./autogen.sh \
      && ./configure --prefix=/opt/aws-ofi-nccl/install \
         --with-libfabric=/opt/amazon/efa/ \
         --with-cuda=/usr/local/cuda \
         --with-nccl=/opt/nccl/build \
         --with-mpi=/usr/local/mpi/ \
      && make && make install \
      && popd

    if [ "$INSTALL_TESTS" == "true" ]; then
      # NCCL Tests
      git clone https://github.com/NVIDIA/nccl-tests.git /opt/nccl-tests \
        && pushd /opt/nccl-tests \
        && git checkout ${NCCL_TESTS_VERSION} \
        && make MPI=1 \
          MPI_HOME=/usr/local/mpi/ \
          CUDA_HOME=/usr/local/cuda \
          NCCL_HOME=/opt/nccl/build \
          NVCC_GENCODE="-gencode=arch=compute_86,code=sm_86 -gencode=arch=compute_80,code=sm_80 -gencode=arch=compute_75,code=sm_75 -gencode=arch=compute_70,code=sm_70 -gencode=arch=compute_60,code=sm_60" \
        && popd
    fi

    export LD_PRELOAD=/opt/nccl/build/lib/libnccl.so:/opt/aws-ofi-nccl/install/lib/libnccl-net.so

    cd /tmp/openmpi; pushd openmpi-4.1.4; ./configure --prefix=/shared --with-libfabric=/opt/amazon/efa --with-sge --with-hwloc=internal; make all install; popd
  else
   cd /tmp/openmpi;  pushd openmpi-4.1.4; ./configure --prefix=/shared --with-sge --with-hwloc=internal; make all install; popd
  fi

fi
