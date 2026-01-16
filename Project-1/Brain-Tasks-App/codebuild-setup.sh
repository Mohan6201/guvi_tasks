#!/bin/bash

# AWS CodeBuild Project Setup Script
# Make sure AWS CLI is configured with appropriate permissions

# Variables
PROJECT_NAME="brain-tasks-app-build"
REGION="us-east-1"
SERVICE_ROLE_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/CodeBuildServiceRole"

echo "Creating CodeBuild project: ${PROJECT_NAME}..."

# Create CodeBuild project
aws codebuild create-project \
    --name ${PROJECT_NAME} \
    --source type=CODECOMMIT,location=$(aws codecommit get-repository --repository-name brain-tasks-app --query 'repositoryMetadata.cloneUrlHttp' --output text 2>/dev/null || echo "https://github.com/Vennilavan12/Brain-Tasks-App.git") \
    --artifacts type=NO_ARTIFACTS \
    --environment type=MANAGED_IMAGE,image=aws/codebuild/amazonlinux2-x86_64-standard:5.0,computeType=BUILD_GENERAL1_SMALL \
    --service-role ${SERVICE_ROLE_ARN} \
    --timeout-in-minutes 15 \
    --logs-config groupname=aws/codebuild/${PROJECT_NAME},status=ENABLED \
    --region ${REGION} || echo "Project may already exist"

echo "CodeBuild project setup complete!"
echo "Project name: ${PROJECT_NAME}"
echo "To start a build, run: aws codebuild start-build --project-name ${PROJECT_NAME}"
