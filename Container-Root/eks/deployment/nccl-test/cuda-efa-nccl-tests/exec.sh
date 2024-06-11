#!/bin/bash

source .env

if [ "$1" == "" ]; then
	CMD=/bin/bash
else
	CMD=$@
fi

docker container exec -it ${CONTAINER} $CMD 

