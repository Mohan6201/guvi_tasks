#!/bin/bash

# AWS Cleanup Script
# Usage: ./cleanup.sh [dev|prod]

set -e

ENVIRONMENT=${1:-dev}
AWS_REGION="us-east-1"

echo "Cleaning up AWS resources for $ENVIRONMENT environment"

# Determine configuration based on environment
if [ "$ENVIRONMENT" = "dev" ]; then
    INSTANCE_NAME="devops-react-app-dev"
    SECURITY_GROUP_NAME="devops-react-app-dev-sg"
    KEY_NAME="devops-react-app-key"
elif [ "$ENVIRONMENT" = "prod" ]; then
    INSTANCE_NAME="devops-react-app-prod"
    SECURITY_GROUP_NAME="devops-react-app-prod-sg"
    KEY_NAME="devops-react-app-key"
else
    echo "Invalid environment. Use 'dev' or 'prod'"
    exit 1
fi

# Find and terminate instances
echo "Finding instances..."
INSTANCE_IDS=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=running,stopped" \
    --region "$AWS_REGION" \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text)

if [ -n "$INSTANCE_IDS" ]; then
    echo "Terminating instances: $INSTANCE_IDS"
    aws ec2 terminate-instances --instance-ids $INSTANCE_IDS --region "$AWS_REGION"
    
    echo "Waiting for instances to terminate..."
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS --region "$AWS_REGION"
else
    echo "No instances found to terminate"
fi

# Delete security group
echo "Deleting security group..."
SG_ID=$(aws ec2 describe-security-groups \
    --group-names "$SECURITY_GROUP_NAME" \
    --region "$AWS_REGION" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || true)

if [ -n "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
    echo "Deleting security group: $SG_ID"
    aws ec2 delete-security-group --group-id "$SG_ID" --region "$AWS_REGION"
else
    echo "Security group not found"
fi

# Delete key pair
echo "Deleting key pair..."
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    aws ec2 delete-key-pair --key-name "$KEY_NAME" --region "$AWS_REGION"
    rm -f "${KEY_NAME}.pem"
    echo "Key pair deleted"
else
    echo "Key pair not found"
fi

# Clean up local files
rm -f "${ENVIRONMENT}-instance-info.txt"

echo "Cleanup completed for $ENVIRONMENT environment!"
