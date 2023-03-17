#!/bin/bash

kubectl -n default delete pod $(kubectl -n default get pod | grep echo | cut -d ' ' -f 1)

