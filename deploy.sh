#!/bin/bash

# Deploy script for Docker images to server
# Usage: ./deploy.sh [dev|prod] [server-ip]

set -e

ENVIRONMENT=${1:-dev}
SERVER_IP=${2:-localhost}
DOCKERHUB_USERNAME="your-dockerhub-username"  # Replace with your Docker Hub username
IMAGE_NAME="devops-react-app"

echo "Deploying $ENVIRONMENT environment to server: $SERVER_IP"

# Determine image tag and repository
if [ "$ENVIRONMENT" = "dev" ]; then
    TAG="dev-latest"
    REPO="$DOCKERHUB_USERNAME/dev"
    CONTAINER_NAME="devops-react-app-dev"
    PORT="8080"
elif [ "$ENVIRONMENT" = "prod" ]; then
    TAG="prod-latest"
    REPO="$DOCKERHUB_USERNAME/prod"
    CONTAINER_NAME="devops-react-app-prod"
    PORT="80"
else
    echo "Invalid environment. Use 'dev' or 'prod'"
    exit 1
fi

echo "Using image: $REPO:$TAG"
echo "Container name: $CONTAINER_NAME"
echo "Port: $PORT"

# Pull the latest image
echo "Pulling latest image from Docker Hub..."
docker pull "$REPO:$TAG"

# Stop and remove existing container if it exists
echo "Stopping existing container..."
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

# Run the new container
echo "Starting new container..."
docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    -p "$PORT:80" \
    -e NODE_ENV=production \
    "$REPO:$TAG"

echo "Deployment completed successfully!"
echo "Application is running on http://$SERVER_IP:$PORT"

# Wait a moment and check if container is running
sleep 3
if docker ps | grep -q "$CONTAINER_NAME"; then
    echo "✅ Container is running successfully"
else
    echo "❌ Container failed to start"
    docker logs "$CONTAINER_NAME"
    exit 1
fi
