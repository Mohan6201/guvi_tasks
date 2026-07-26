#!/bin/bash
set -e

# EC2 user-data for the APP instance: Docker only, no Jenkins.
# The running app container is started later by deploy.sh (manually or via Jenkins SSH).

apt-get update -y
apt-get install -y curl

curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker
