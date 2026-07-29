#!/bin/bash

# Version of kubectl to install
KUBECTL_VERSION=v1.36.0

echo ""
echo "Installing kubectl ${KUBECTL_VERSION} ..."


ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
  GOARCH=arm64
else
  GOARCH=amd64
fi

OS=$(uname)
OS_LOWER=$(echo $OS | tr '[:upper:]' '[:lower:]')

# Install kubectl
# Reference: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
# curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
URL=https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS_LOWER}/${GOARCH}/kubectl
echo "$URL"
curl -Lo kubectl $URL
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin
kubectl version --client

echo ""
echo "Installing kubectl bash completion ..."
# Install bash completion
# Reference: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#enable-kubectl-autocompletion
echo 'source /usr/share/bash-completion/bash_completion' >> /root/.bashrc
echo 'source <(kubectl completion bash)' >> /root/.bashrc
echo 'alias k=kubectl' >> /root/.bashrc
echo 'complete -o default -F __start_kubectl k' >> /root/.bashrc

