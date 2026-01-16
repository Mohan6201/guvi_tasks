#!/bin/bash

# Jenkins Setup Script for Trend App Deployment

# Install required plugins
echo "Installing Jenkins plugins..."
jenkins-plugin-cli --plugins \
    docker-workflow \
    git \
    kubernetes \
    pipeline-stage-view \
    workflow-aggregator \
    email-ext \
    credentials-binding \
    github

# Create Docker credentials
echo "Setting up DockerHub credentials..."
# Note: This needs to be done manually in Jenkins UI
# Manage Jenkins -> Manage Credentials -> Global -> Add Credentials
# Username: your DockerHub username
# Password: your DockerHub password
# ID: dockerhub-credentials

# Create Kubernetes config credentials
echo "Setting up Kubernetes credentials..."
# Note: This needs to be done manually in Jenkins UI
# Manage Jenkins -> Manage Credentials -> Global -> Add Credentials
# Kind: Secret file
# File: your kubeconfig file
# ID: kubeconfig

# Create GitHub webhook
echo "Setting up GitHub webhook..."
# Note: This needs to be done manually in GitHub repository settings
# Repository -> Settings -> Webhooks -> Add webhook
# Payload URL: http://your-jenkins-ip:8080/github-webhook/
# Content type: application/json
# Events: Just the push event

echo "Jenkins setup complete!"
echo "Please complete the manual steps mentioned above."
