#!/usr/bin/env bash

#
# 1.  Provision the ARM machine
#
#   A.  Part 1 will get you the ID for the AMI, which you need pass to `aws ec2 run-instances ...`
#   B.  Part 2 uses the ID for the AMI to create the things
#
# 2.  Run this script to build and push the images
#
#
# Part 1 (getting the ID for the AMI)
#
#  Capture the JSON into a file because it's huge
#
#   To find the image ID (note this takes a LONG time it's 262MB!):
#     aws ec2 describe-images | jq -r ".Images" > images.json
#
#   Best way to extract the image ID:
#
#     ruby -r 'json' -r 'date' -e 'puts JSON.parse(File.read("images.json")).filter{|i| i["OwnerId"] == "099720109477" && i["Architecture"] == "arm64" && i["State"] == "available" && i["Name"] =~ /ubuntu-jammy/i && i["Name"] =~ /^ubuntu\/images\//i}.sort{|i1, i2| DateTime.parse(i2["CreationDate"]) <=> DateTime.parse(i1["CreationDate"])}.first.to_json' | jq -r '.ImageId'
#
#   Notes from irb usage (kept for reference):
#
#     irb
#     require 'json'
#     require 'date'
#     puts JSON.parse(File.read("images.json"))
#        .filter{|i| i["OwnerId"] == "099720109477" && i["Architecture"] == "arm64" && i["State"] == "available" && i["Name"] =~ /ubuntu-jammy/i && i["Name"] =~ /^ubuntu\/images\//i}
#        .sort{|i1, i2| DateTime.parse(i2["CreationDate"]) <=> DateTime.parse(i1["CreationDate"])}
#        .map{|i| "#{i["ImageId"]} - #{i["Name"]}"}
#        .join("\n")
#
#   To use ruby from the CLI to parse the AMI ID (kept for reference):
#
#     ruby -r 'json' -r 'date' -e 'puts JSON.parse(File.read("images.json")).filter{|i| i["OwnerId"] == "099720109477" && i["Architecture"] == "arm64" && i["State"] == "available" && i["Name"] =~ /ubuntu-jammy/i && i["Name"] =~ /^ubuntu\/images\//i}.sort{|i1, i2| DateTime.parse(i2["CreationDate"]) <=> DateTime.parse(i1["CreationDate"])}.map{|i| "#{i["ImageId"]} - #{i["Name"]}"}.join("\n")'

#
#     # aws ec2 run-instances --image-id ami-0ee02425a4c7e78bb --count 1 --instance-type c6g.xlarge --key-name ben_0 --security-group-ids sg-903004f8 --subnet-id subnet-6e7f829e
#
#
#
# Once you have the ami's image id, stick in variable:
#
#######  Running all the things
#
# # save images.json locally if don't have it
# aws ec2 describe-images | jq -r ".Images" > images.json
#
# # If need to extract the AMI ID.  See next if alreay have it
# imageid="$(ruby -r 'json' -r 'date' -e 'puts JSON.parse(File.read("images.json")).filter{|i| i["OwnerId"] == "099720109477" && i["Architecture"] == "arm64" && i["State"] == "available" && i["Name"] =~ /ubuntu-jammy/i && i["Name"] =~ /^ubuntu\/images\//i}.sort{|i1, i2| DateTime.parse(i2["CreationDate"]) <=> DateTime.parse(i1["CreationDate"])}.first.to_json' | jq -r '.ImageId')"
# # If already have it:
# imageid="ami-06edaf01ee52adb1e"     # 2023-08-23
#
# # Create the ec2 instance using imageid variable from previous step
# aws ec2 run-instances --image-id "${imageid}" --count 1 --instance-type c6g.xlarge --key-name ben_0
# # wait for instance to initialize and get a public IP
# # aws ec2 describe-instances | jq -r '.Reservations | map(.Instances) | map(.PublicIpAddress)'
# # Get the public IP of the machine
# iid="$(aws ec2 describe-instances | jq -r '.Reservations[].Instances[].InstanceId')"
# vmip="$(aws ec2 describe-instances | jq -r '.Reservations[].Instances[].PublicIpAddress')"
# sgid="$(aws ec2 describe-instances | jq -r '.Reservations[].Instances[].SecurityGroups[].GroupId')"
# # Allow SSH in the security group
# aws ec2 authorize-security-group-ingress --group-id "${sgid}" --protocol tcp --port 22 --cidr 0.0.0.0/0
# # Copy docker creds
# ssh ubuntu@${vmip} 'mkdir -p /home/ubuntu/.docker && sudo mkdir -p /root/.docker'
# scp /home/ben/.docker/config.json ubuntu@${vmip}:/home/ubuntu/.docker/config.json
# ssh ubuntu@${vmip} 'sudo cp /home/ubuntu/.docker/config.json /root/.docker/config.json'
# # Invoke the script
# scp scripts/provision-build-arm-release.sh ubuntu@${vmip}:/home/ubuntu/
# # automatic doesn't work due to a terminal issue
# # ssh ubuntu@${vmip} 'sudo ./provision-build-arm-release.sh'
# ssh ubuntu@${vmip}
#   sudo ./provision-build-arm-release.sh
# # Destroy the instance
# aws ec2 terminate-instances --instance-ids "${iid}"



###
# This script is meant to run on a fresh Ubuntu ARM64 ec2 instance.
# It will build and push malan latest arm releases
###

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
if ! [ -f "$HOME/.docker/config.json" ]; then
  mkdir -p $HOME/.docker
  echo "${DOCKER_CONFIG}" > $HOME/.docker/config.json
fi

if ! [ -d "malan" ]; then
  git clone https://github.com/FreedomBen/malan.git
fi

cd malan

./scripts/build-arm-dev.sh
./scripts/build-arm-release.sh

./scripts/push-arm-dev.sh
./scripts/push-arm-release.sh
