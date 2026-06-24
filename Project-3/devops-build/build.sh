#!/bin/bash
set -e

# Determine branch — Jenkins sets GIT_BRANCH, fallback to git for local runs
BRANCH="${GIT_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"
# Strip origin/ prefix if present
BRANCH="${BRANCH#origin/}"

# Use Jenkins BUILD_NUMBER if available, else short commit hash
TAG="${BUILD_NUMBER:-$(git rev-parse --short HEAD)}"

# Route to dev or prod DockerHub repo based on branch
if [ "$BRANCH" = "master" ] || [ "$BRANCH" = "main" ]; then
    IMAGE_NAME="${DOCKERHUB_USERNAME}/prod"
else
    IMAGE_NAME="${DOCKERHUB_USERNAME}/dev"
fi

echo "Branch       : $BRANCH"
echo "Image        : $IMAGE_NAME"
echo "Tag          : $TAG"

docker build -t "$IMAGE_NAME:$TAG" .
docker tag "$IMAGE_NAME:$TAG" "$IMAGE_NAME:latest"

echo "$DOCKERHUB_PASSWORD" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

docker push "$IMAGE_NAME:$TAG"
docker push "$IMAGE_NAME:latest"

echo "Successfully pushed $IMAGE_NAME:$TAG"
