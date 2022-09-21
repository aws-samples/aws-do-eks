#!/bin/sh

if [ -d /etc/apt ]; then
        [ -n "$http_proxy" ] && echo "Acquire::http::proxy \"${http_proxy}\";" > /etc/apt/apt.conf; \
        [ -n "$https_proxy" ] && echo "Acquire::https::proxy \"${https_proxy}\";" >> /etc/apt/apt.conf; \
        [ -f /etc/apt/apt.conf ] && cat /etc/apt/apt.conf
fi

# Customize shell
echo "alias ll='ls -alh --color=auto'" >> ~/.bashrc
echo "alias k=kubectl" >> ~/.bashrc
echo "export PATH=$PATH:/opt/view/bin:/bin:/usr/bin:/usr/local/bin" >> /etc/bashrc
echo "export PATH=$PATH:/opt/view/bin" >> ~/.bashrc
echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib64/openmpi/lib" >> ~/.bashrc
ln -s /app/inputs/ /inputs

# Add yum requirements
yum -y install \
      unzip \
      libgomp \
      libatomic \
      openssh-clients \
      openssh-server \
      procps \
      openmpi-devel.x86_64 \
      which \
      gettext \
      htop \
&&  yum clean all \
&&  rm -rf /var/cache/yum

# Generate host keys (required on amazon linux 2)
ssh-keygen -A

# Add priviledge separation directoy to run sshd as root.
mkdir -p /var/run/sshd

# Allow OpenSSH to talk to containers without asking for confirmation
# by disabling StrictHostKeyChecking.
# mpi-operator mounts the .ssh folder from a Secret. For that to work, we need
# to disable UserKnownHostsFile to avoid write permissions.
# Disabling StrictModes avoids directory and files read permission checks.
port=22
sed -i "s/[ #]\(.*StrictHostKeyChecking \).*/ \1no/g" /etc/ssh/ssh_config \
    && echo "    UserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config \
    && sed -i "s/[ #]\(.*Port \).*/ \1$port/g" /etc/ssh/ssh_config \
    && sed -i "s/#\(StrictModes \).*/\1no/g" /etc/ssh/sshd_config \
    && sed -i "s/#\(Port \).*/\1$port/g" /etc/ssh/sshd_config


# Install AWS CLI
curl -o /tmp/awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
pushd /tmp
unzip awscliv2.zip 
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip
popd
aws --version

# Install kubectl
curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.19.6/2021-01-05/bin/linux/amd64/kubectl
chmod +x ./kubectl
mv ./kubectl /usr/local/bin
kubectl version --client

