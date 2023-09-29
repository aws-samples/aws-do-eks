#!/bin/bash

# Install Docker on Ubuntu using snap

sudo snap install docker

sudo addgroup --system docker
sudo adduser ubuntu docker
newgrp docker

sudo snap disable docker
sudo snap enable docker
