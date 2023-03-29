#!/bin/bash


pushd ../../../etcd
./remove.sh
popd

pushd ../../../volcano
./remove.sh
popd

