#!/bin/bash

kubectl apply -f ./queue.yaml

# Provide time for the queue to become active
sleep 3

kubectl apply -f ./vcjob.yaml

