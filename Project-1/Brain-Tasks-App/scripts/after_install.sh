#!/bin/bash

# AfterInstall hook for CodeDeploy
# This script runs after the new application version is installed

set -e

echo "Starting AfterInstall hook..."

# Apply Kubernetes manifests
echo "Applying Kubernetes manifests..."
kubectl apply -f k8s/ecr-secret.yaml -n brain-tasks
kubectl apply -f k8s/deployment.yaml -n brain-tasks
kubectl apply -f k8s/service.yaml -n brain-tasks

# Wait for deployment to be ready
echo "Waiting for deployment to be ready..."
kubectl rollout status deployment/brain-tasks-app -n brain-tasks --timeout=300s

echo "AfterInstall hook completed successfully!"
