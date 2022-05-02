#!/usr/bin/env bash

#
# This script is meant to run on s fresh ubuntu ARM64 ec2 instance.
# It will build and push malan latest arm releases
#

set -e

DOCKER_CONFIG='
{
  "auths": {
    "https://index.docker.io/v1/": {
      "auth": "<replace me>"
    },
    "quay.io": {
      "auth": "<replace me>"
    }
  }
}
'

cd /root

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get -y upgrade

sudo apt-get -y install \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  vim \
  git \
  htop

# Install docker:  https://docs.docker.com/engine/install/ubuntu/

# Remove any old installs
sudo apt-get -y remove docker docker.io containerd runc

# Add docker key and apt repo
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install docker
sudo apt-get update
sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Setup docker auth
mkdir -p $HOME/.docker
echo "${DOCKER_CONFIG}" > $HOME/.docker/config.json

git clone https://github.com/FreedomBen/malan.git

cd malan

./scripts/build-arm-dev.sh
./scripts/build-arm-release.sh

./scripts/push-arm-dev.sh
./scripts/push-arm-release.sh
