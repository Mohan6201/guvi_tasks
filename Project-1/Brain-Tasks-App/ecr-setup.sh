#!/bin/bash

# AWS ECR Repository Setup Script
# Make sure AWS CLI is configured with appropriate permissions

# Variables
AWS_REGION="us-east-1"
REPOSITORY_NAME="brain-tasks-app"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Setting up ECR repository for ${REPOSITORY_NAME}..."

# Create ECR repository
aws ecr create-repository \
    --repository-name ${REPOSITORY_NAME} \
    --region ${AWS_REGION} \
    --image-scanning-configuration scanOnPush=true \
    --image-tag-mutability MUTABLE || echo "Repository may already exist"

# Get repository URI
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY_NAME}"
echo "ECR Repository URI: ${ECR_URI}"

# Authenticate Docker with ECR
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

echo "ECR setup complete!"
echo "To push your image, run:"
echo "docker tag brain-tasks-app:latest ${ECR_URI}:latest"
echo "docker push ${ECR_URI}:latest"
