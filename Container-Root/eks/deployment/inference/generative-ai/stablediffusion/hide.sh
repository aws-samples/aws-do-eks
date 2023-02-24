#!/bin/bash

kill -9 $(ps -aef | grep port-forward | grep stable-diffusion | awk '{print $2}') 

