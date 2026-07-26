#!/bin/bash
set -e

# AWS Cleanup Script
# Usage: ./cleanup.sh [app|jenkins|all]
#
# Expects AWS_DEFAULT_REGION and EC2_KEY_NAME to already be exported from .env.

TARGET="${1:-all}"
AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
KEY_NAME="${EC2_KEY_NAME}"

terminate_role() {
    local role="$1"
    local instance_name="devops-build-$role"
    local sg_name="devops-build-$role-sg"

    echo "--- Cleaning up $role instance ---"

    local instance_ids
    instance_ids=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$instance_name" "Name=instance-state-name,Values=running,stopped" \
        --region "$AWS_REGION" \
        --query 'Reservations[*].Instances[*].InstanceId' \
        --output text)

    if [ -n "$instance_ids" ]; then
        echo "Terminating instances: $instance_ids"
        aws ec2 terminate-instances --instance-ids $instance_ids --region "$AWS_REGION"
        echo "Waiting for instances to terminate..."
        aws ec2 wait instance-terminated --instance-ids $instance_ids --region "$AWS_REGION"
    else
        echo "No $role instances found"
    fi

    local sg_id
    sg_id=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=$sg_name" \
        --region "$AWS_REGION" \
        --query 'SecurityGroups[0].GroupId' \
        --output text 2>/dev/null || true)

    if [ -n "$sg_id" ] && [ "$sg_id" != "None" ]; then
        echo "Deleting security group: $sg_id"
        aws ec2 delete-security-group --group-id "$sg_id" --region "$AWS_REGION"
    else
        echo "Security group $sg_name not found"
    fi

    rm -f "${role}-instance-info.txt"
}

case "$TARGET" in
    app)
        terminate_role app
        ;;
    jenkins)
        terminate_role jenkins
        ;;
    all)
        terminate_role app
        terminate_role jenkins
        ;;
    *)
        echo "Invalid target. Use 'app', 'jenkins', or 'all'"
        exit 1
        ;;
esac

# Key pair is shared across both instances — only delete once, after both are gone
if [ "$TARGET" = "all" ]; then
    if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
        echo "Deleting key pair: $KEY_NAME"
        aws ec2 delete-key-pair --key-name "$KEY_NAME" --region "$AWS_REGION"
        rm -f "${KEY_NAME}.pem"
    else
        echo "Key pair not found"
    fi
fi

echo "Cleanup completed for target: $TARGET"
