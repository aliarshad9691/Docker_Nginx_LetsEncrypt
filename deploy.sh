#!/usr/bin/env bash

# Update apt-get
apt-get update

# Lets remove any old Docker installations.
apt-get remove -y docker docker-engine docker-ce docker.io

# Install Docker dependencies & git.
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    git

# Adding Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Verify fingerprint
apt-key fingerprint 0EBFCD88

# Adding repository
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

# Update apt-get
apt-get update

# Install Docker CE
apt-get install -y docker-ce

