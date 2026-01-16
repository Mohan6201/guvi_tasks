#!/bin/bash

# Build script for Docker images
# Usage: ./build.sh [dev|prod]

set -e

# Get the current branch name
BRANCH=${1:-$(git rev-parse --abbrev-ref HEAD)}
IMAGE_NAME="devops-react-app"
DOCKERHUB_USERNAME="your-dockerhub-username"  # Replace with your Docker Hub username

echo "Building Docker image for branch: $BRANCH"

# Determine tag based on branch
if [ "$BRANCH" = "dev" ]; then
    TAG="dev-latest"
    REPO="$DOCKERHUB_USERNAME/dev"
elif [ "$BRANCH" = "master" ] || [ "$BRANCH" = "main" ]; then
    TAG="prod-latest"
    REPO="$DOCKERHUB_USERNAME/prod"
else
    TAG="feature-$BRANCH"
    REPO="$DOCKERHUB_USERNAME/dev"
fi

echo "Building image: $IMAGE_NAME:$TAG"
echo "Target repository: $REPO"

# Build the Docker image
docker build -t "$IMAGE_NAME:$TAG" .

# Tag for Docker Hub
docker tag "$IMAGE_NAME:$TAG" "$REPO:$TAG"

echo "Build completed successfully!"
echo "Image tagged as: $REPO:$TAG"
echo ""
echo "To push to Docker Hub, run: docker push $REPO:$TAG"
