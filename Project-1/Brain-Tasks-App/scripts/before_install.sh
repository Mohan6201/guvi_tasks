#!/bin/bash

# BeforeInstall hook for CodeDeploy
# This script runs before the new application version is installed

set -e

echo "Starting BeforeInstall hook..."

# Update kubeconfig if needed
if [ -n "$CLUSTER_NAME" ] && [ -n "$REGION" ]; then
    echo "Updating kubeconfig for EKS cluster: $CLUSTER_NAME"
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
fi

# Create namespace if it doesn't exist
kubectl create namespace brain-tasks --dry-run=client -o yaml | kubectl apply -f -

# Create ECR registry secret if it doesn't exist
if ! kubectl get secret ecr-registry-secret -n brain-tasks; then
    echo "Creating ECR registry secret..."
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=${REGION:-us-east-1}
    
    kubectl create secret docker-registry ecr-registry-secret \
        --docker-server=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com \
        --docker-username=AWS \
        --docker-password=$(aws ecr get-login-password --region ${AWS_REGION}) \
        --namespace=brain-tasks
fi

echo "BeforeInstall hook completed successfully!"
