#!/bin/bash

# Source: https://github.com/stern/stern
# Note: depends on install-krew.sh

export PATH=$PATH:/root/.krew/bin

kubectl krew install stern

