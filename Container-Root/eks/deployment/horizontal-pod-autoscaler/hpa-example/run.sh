#!/bin/bash

source .env

echo ""

for f in $(ls *.yaml-template); do
	echo "Generating manifest from template $f ..."
	filename=$(echo $f | cut -d '.' -f 1)
	cat ./$f | envsubst > ./${filename}.yaml
done

echo ""
echo "Applying base manifests ..."

kubectl apply -f ./namespace.yaml
kubectl apply -f ./php-apache.yaml

