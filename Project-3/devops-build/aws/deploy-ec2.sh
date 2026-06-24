#!/bin/bash
set -e

ENVIRONMENT=${1:-dev}
AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
INSTANCE_TYPE="t2.micro"
KEY_NAME="${EC2_KEY_NAME}"

echo "Deploying to AWS EC2 for $ENVIRONMENT environment"

if [ "$ENVIRONMENT" = "dev" ]; then
    INSTANCE_NAME="ecommerce-dev"
    SG_NAME="ecommerce-dev-sg"
    PORT="80"
elif [ "$ENVIRONMENT" = "prod" ]; then
    INSTANCE_NAME="ecommerce-prod"
    SG_NAME="ecommerce-prod-sg"
    PORT="80"
else
    echo "Invalid environment. Use 'dev' or 'prod'"
    exit 1
fi

# Detect your current public IP for SSH restriction
MY_IP=$(curl -s ifconfig.me)
echo "Your IP: $MY_IP"

# Fetch latest Ubuntu 22.04 AMI
AMI_ID=$(aws ec2 describe-images \
    --region "$AWS_REGION" \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
              "Name=state,Values=available" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text)

echo "Using AMI: $AMI_ID"

# Create security group
SG_ID=$(aws ec2 create-security-group \
    --group-name "$SG_NAME" \
    --description "Security group for $ENVIRONMENT React app" \
    --region "$AWS_REGION" \
    --query 'GroupId' \
    --output text)

echo "Security Group: $SG_ID"

# Port 80 — open to everyone
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" --protocol tcp --port 80 \
    --cidr 0.0.0.0/0 --region "$AWS_REGION"

# Port 8080 (Jenkins) — open to everyone
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" --protocol tcp --port 8080 \
    --cidr 0.0.0.0/0 --region "$AWS_REGION"

# Port 22 — SSH restricted to your IP only
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" --protocol tcp --port 22 \
    --cidr "$MY_IP/32" --region "$AWS_REGION"

# Create key pair if it doesn't exist
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    aws ec2 create-key-pair \
        --key-name "$KEY_NAME" \
        --region "$AWS_REGION" \
        --query 'KeyMaterial' \
        --output text > "${KEY_NAME}.pem"
    chmod 400 "${KEY_NAME}.pem"
    echo "Key pair saved as ${KEY_NAME}.pem"
fi

# Launch instance with setup script as user_data
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --user-data file://../scripts/setup_ec2.sh \
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
echo "  Instance is running!"
echo "  Public IP    : $PUBLIC_IP"
echo "  App URL      : http://$PUBLIC_IP"
echo "  Jenkins URL  : http://$PUBLIC_IP:8080"
echo "  SSH command  : ssh -i ${KEY_NAME}.pem ubuntu@$PUBLIC_IP"
echo "============================================"
echo ""
echo "Wait 3-5 minutes for Jenkins and Docker to finish installing."
echo "Then SSH in and run: ./get_jenkins_password.sh"

cat > "${ENVIRONMENT}-instance-info.txt" <<EOF
Instance ID  : $INSTANCE_ID
Public IP    : $PUBLIC_IP
Security Group: $SG_ID
App URL      : http://$PUBLIC_IP
Jenkins URL  : http://$PUBLIC_IP:8080
SSH command  : ssh -i ${KEY_NAME}.pem ubuntu@$PUBLIC_IP
EOF
