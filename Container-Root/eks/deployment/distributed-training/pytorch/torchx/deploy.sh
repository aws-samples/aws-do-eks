#!/bin/bash

# Install volcano

pushd ../../../volcano
./deploy.sh
popd

pushd ../../../etcd
./deploy.sh
popd

# torchx should alredy be installed in the do-eks container
# if needed, it can be installed using the line below
#pip install torchx[kubernetes]


