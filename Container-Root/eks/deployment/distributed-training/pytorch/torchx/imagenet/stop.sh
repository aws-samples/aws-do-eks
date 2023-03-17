#!/bin/bash

for j in $(torchx list -s kubernetes | grep main | grep RUNNING | cut -d ' ' -f 1); do echo stopping $j; torchx cancel $j; done 

