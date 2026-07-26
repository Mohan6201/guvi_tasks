#!/bin/bash
set -e

# Launches the single app t2.micro required by the spec:
#   - port 80 open to anyone (the app)
#   - port 22 restricted to the operator's own IP only
#
# Expects AWS_DEFAULT_REGION and EC2_KEY_NAME to already be exported from .env
# (see README — never hardcode these).

AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
INSTANCE_TYPE="t2.micro"
KEY_NAME="${EC2_KEY_NAME}"
INSTANCE_NAME="devops-build-app"
SG_NAME="devops-build-app-sg"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Provisioning app instance in $AWS_REGION"

MY_IP=$(curl -s ifconfig.me)
echo "Your IP: $MY_IP"

AMI_ID=$(aws ec2 describe-images \
    --region "$AWS_REGION" \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
              "Name=state,Values=available" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text)

echo "Using AMI: $AMI_ID"

EXISTING_SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SG_NAME" \
    --region "$AWS_REGION" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || true)

if [ -n "$EXISTING_SG_ID" ] && [ "$EXISTING_SG_ID" != "None" ]; then
    SG_ID="$EXISTING_SG_ID"
    echo "Security Group already exists, reusing: $SG_ID"
else
    SG_ID=$(aws ec2 create-security-group \
        --group-name "$SG_NAME" \
        --description "App instance - port 80 public, SSH restricted to operator IP" \
        --region "$AWS_REGION" \
        --query 'GroupId' \
        --output text)
    echo "Security Group: $SG_ID"

    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" --protocol tcp --port 80 \
        --cidr 0.0.0.0/0 --region "$AWS_REGION"

    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" --protocol tcp --port 22 \
        --cidr "$MY_IP/32" --region "$AWS_REGION"
fi

if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    aws ec2 create-key-pair \
        --key-name "$KEY_NAME" \
        --region "$AWS_REGION" \
        --query 'KeyMaterial' \
        --output text > "${KEY_NAME}.pem"
    chmod 400 "${KEY_NAME}.pem"
    echo "Key pair saved as ${KEY_NAME}.pem"
fi

INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --user-data "$(cat "${SCRIPT_DIR}/../scripts/setup_app.sh")" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --region "$AWS_REGION" \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Instance launched: $INSTANCE_ID"
echo "Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"

PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$AWS_REGION" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo ""
echo "============================================"
echo "  App instance is running!"
echo "  Public IP    : $PUBLIC_IP"
echo "  App URL      : http://$PUBLIC_IP"
echo "  SSH command  : ssh -i ${KEY_NAME}.pem ubuntu@$PUBLIC_IP"
echo "============================================"
echo ""
echo "Wait ~1 minute for Docker to finish installing, then run deploy.sh"
echo "against this host (set APP_SERVER_HOST=$PUBLIC_IP in .env)."

cat > "app-instance-info.txt" <<EOF
Instance ID   : $INSTANCE_ID
Public IP     : $PUBLIC_IP
Security Group: $SG_ID
App URL       : http://$PUBLIC_IP
SSH command   : ssh -i ${KEY_NAME}.pem ubuntu@$PUBLIC_IP
EOF
