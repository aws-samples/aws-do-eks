#!/bin/bash

source .env

docker ps -a | grep ${CONTAINER}

