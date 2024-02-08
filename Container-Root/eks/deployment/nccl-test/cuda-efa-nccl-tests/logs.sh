#!/bin/bash

source .env

docker container logs -f ${CONTAINER}

