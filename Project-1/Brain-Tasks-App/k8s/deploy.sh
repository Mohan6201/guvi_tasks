#!/bin/bash

# Kubernetes Deployment Script
# Make sure kubectl is configured to connect to your EKS cluster

echo "Deploying Brain Tasks App to Kubernetes..."

# Apply ECR secret (replace BASE64_ENCODED_DOCKER_CONFIG with actual value)
# To get the base64 value, run:
# aws ecr get-login-password --region us-east-1 | base64
# Then create the docker config and encode it
kubectl apply -f ecr-secret.yaml

# Apply deployment
kubectl apply -f deployment.yaml

# Apply service
kubectl apply -f service.yaml

# Check deployment status
echo "Checking deployment status..."
kubectl get pods -l app=brain-tasks-app
kubectl get services
kubectl get ingress

echo "Deployment complete!"
echo "To get the external IP, run: kubectl get service brain-tasks-app-service"
