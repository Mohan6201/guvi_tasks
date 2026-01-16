#!/bin/bash

# AWS EC2 Deployment Script
# Usage: ./deploy-ec2.sh [dev|prod]

set -e

ENVIRONMENT=${1:-dev}
AWS_REGION="us-east-1"
INSTANCE_TYPE="t2.micro"
AMI_ID="ami-0c55b159cbfafe1f0"  # Amazon Linux 2 AMI (update as needed)

echo "Deploying to AWS EC2 for $ENVIRONMENT environment"

# Determine configuration based on environment
if [ "$ENVIRONMENT" = "dev" ]; then
    INSTANCE_NAME="devops-react-app-dev"
    SECURITY_GROUP_NAME="devops-react-app-dev-sg"
    KEY_NAME="devops-react-app-key"
    PORT="8080"
elif [ "$ENVIRONMENT" = "prod" ]; then
    INSTANCE_NAME="devops-react-app-prod"
    SECURITY_GROUP_NAME="devops-react-app-prod-sg"
    KEY_NAME="devops-react-app-key"
    PORT="80"
else
    echo "Invalid environment. Use 'dev' or 'prod'"
    exit 1
fi

# Get your current IP address for SSH access
MY_IP=$(curl -s ifconfig.me)
echo "Your IP address: $MY_IP"

# Create security group
echo "Creating security group..."
SG_ID=$(aws ec2 create-security-group \
    --group-name "$SECURITY_GROUP_NAME" \
    --description "Security group for $ENVIRONMENT React app" \
    --region "$AWS_REGION" \
    --query 'GroupId' \
    --output text)

echo "Security Group created with ID: $SG_ID"

# Add HTTP access rule (anyone can access the app)
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port "$PORT" \
    --cidr 0.0.0.0/0 \
    --region "$AWS_REGION"

# Add SSH access rule (only from your IP)
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 22 \
    --cidr "$MY_IP/32" \
    --region "$AWS_REGION"

# Create key pair if it doesn't exist
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    echo "Creating key pair..."
    aws ec2 create-key-pair \
        --key-name "$KEY_NAME" \
        --region "$AWS_REGION" \
        --query 'KeyMaterial' \
        --output text > "${KEY_NAME}.pem"
    chmod 400 "${KEY_NAME}.pem"
    echo "Key pair saved as ${KEY_NAME}.pem"
fi

# Launch EC2 instance
echo "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --region "$AWS_REGION" \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Instance launched with ID: $INSTANCE_ID"

# Wait for instance to be running
echo "Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"

# Get public IP address
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$AWS_REGION" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "Instance is running at IP: $PUBLIC_IP"

# Wait a bit more for SSH to be available
echo "Waiting for SSH to be available..."
sleep 30

# Install Docker and deploy the application
echo "Installing Docker and deploying application..."
ssh -o StrictHostKeyChecking=no -i "${KEY_NAME}.pem" ec2-user@"$PUBLIC_IP" << 'EOF'
    # Update system
    sudo yum update -y
    
    # Install Docker
    sudo yum install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -a -G docker ec2-user
    
    # Install Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Create app directory
    mkdir -p /home/ec2-user/app
    cd /home/ec2-user/app
    
    # Pull and run the application
    # Note: Replace with your actual Docker Hub username
    docker run -d \
        --name devops-react-app \
        --restart unless-stopped \
        -p 80:80 \
        your-dockerhub-username/dev:dev-latest
    
    echo "Application deployed successfully!"
EOF

echo "Deployment completed!"
echo "Application URL: http://$PUBLIC_IP:$PORT"
echo "SSH command: ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP"

# Save instance information
cat > "${ENVIRONMENT}-instance-info.txt" << EOF
Instance ID: $INSTANCE_ID
Public IP: $PUBLIC_IP
Security Group: $SG_ID
Key Pair: $KEY_NAME
Application URL: http://$PUBLIC_IP:$PORT
SSH command: ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP
EOF

echo "Instance information saved to ${ENVIRONMENT}-instance-info.txt"
