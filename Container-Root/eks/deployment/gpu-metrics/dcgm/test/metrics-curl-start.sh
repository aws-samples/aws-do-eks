#!/bin/bash

kubectl run metrics-curl --image=appropriate/curl -- sh -c "while true; do date; sleep 10; done" 

