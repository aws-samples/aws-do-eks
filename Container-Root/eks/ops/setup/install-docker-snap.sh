#!/bin/bash

# Install Docker on Ubuntu using snap

snap install docker

addgroup --system docker
adduser ubuntu docker
newgrp docker

snap disable docker
snap enable docker
