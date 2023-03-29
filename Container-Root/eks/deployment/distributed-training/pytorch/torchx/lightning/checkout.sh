#!/bin/bash

rm -rf /tmp/torchx

git clone https://github.com/pytorch/torchx.git /tmp/torchx

pushd /tmp/torchx

git checkout v0.4.0

popd

cp -rf /tmp/torchx/torchx/examples/apps/lightning ./imagenet

