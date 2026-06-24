#!/bin/bash
set -e

# Determine branch — Jenkins sets GIT_BRANCH, fallback to git for local runs
BRANCH="${GIT_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"
BRANCH="${BRANCH#origin/}"

TAG="${BUILD_NUMBER:-$(git rev-parse --short HEAD)}"

if [ "$BRANCH" = "master" ] || [ "$BRANCH" = "main" ]; then
    IMAGE_NAME="${DOCKERHUB_USERNAME}/prod"
    CONTAINER_NAME="ecommerce-prod"
    PORT="80"
else
    IMAGE_NAME="${DOCKERHUB_USERNAME}/dev"
    CONTAINER_NAME="ecommerce-dev"
    PORT="80"
fi

echo "Branch         : $BRANCH"
echo "Image          : $IMAGE_NAME:$TAG"
echo "Container name : $CONTAINER_NAME"
echo "Port           : $PORT"

echo "$DOCKERHUB_PASSWORD" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

docker pull "$IMAGE_NAME:$TAG"

# Stop and remove existing container if running
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    -p "$PORT:80" \
    "$IMAGE_NAME:$TAG"

# Verify container started
sleep 3
if docker ps | grep -q "$CONTAINER_NAME"; then
    echo "App is running at http://$(curl -s ifconfig.me)"
else
    echo "Container failed to start"
    docker logs "$CONTAINER_NAME"
    exit 1
fi
