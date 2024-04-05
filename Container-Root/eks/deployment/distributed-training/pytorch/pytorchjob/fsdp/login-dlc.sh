#!/bin/bash

. .env

REGISTRY=763104351884.dkr.ecr.us-east-1.amazonaws.com

# Login to DLC registry
echo ""
echo "Logging in to DLC registry: $REGISTRY ..."
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $REGISTRY

