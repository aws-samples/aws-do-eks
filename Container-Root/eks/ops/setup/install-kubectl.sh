#!/bin/bash

curl -Lo kubectl https://dl.k8s.io/release/v1.21.9/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin
kubectl version --client --short

