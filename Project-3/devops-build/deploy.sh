#!/bin/bash
set -e

# Deploys the just-built image to the app server over SSH — the app runs on
# its own EC2 instance, separate from wherever this script executes (Jenkins
# host or a local machine), so "deploying" always means a remote docker run.
#
# Expects DOCKERHUB_USERNAME/DOCKERHUB_PASSWORD and APP_SERVER_HOST/
# APP_SERVER_SSH_KEY_PATH/APP_SERVER_SSH_USER to already be exported from .env
# (Jenkins supplies the same variables via credentials bindings).

# Determine branch — Jenkins sets GIT_BRANCH, fallback to git for local runs
BRANCH="${GIT_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"
BRANCH="${BRANCH#origin/}"

TAG="${BUILD_NUMBER:-$(git rev-parse --short HEAD)}"

if [ "$BRANCH" = "master" ] || [ "$BRANCH" = "main" ]; then
    IMAGE_NAME="${DOCKERHUB_USERNAME}/prod"
else
    IMAGE_NAME="${DOCKERHUB_USERNAME}/dev"
fi
CONTAINER_NAME="devops-build-app"
PORT="80"

APP_SERVER_SSH_USER="${APP_SERVER_SSH_USER:-ubuntu}"

echo "Branch         : $BRANCH"
echo "Image          : $IMAGE_NAME:$TAG"
echo "Container name : $CONTAINER_NAME"
echo "Target server  : $APP_SERVER_SSH_USER@$APP_SERVER_HOST"

ssh -o StrictHostKeyChecking=accept-new -i "$APP_SERVER_SSH_KEY_PATH" \
    "$APP_SERVER_SSH_USER@$APP_SERVER_HOST" bash -s <<EOF
set -e
echo "$DOCKERHUB_PASSWORD" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

docker pull "$IMAGE_NAME:$TAG"

docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    -p "$PORT:80" \
    "$IMAGE_NAME:$TAG"

sleep 3
if docker ps | grep -q "$CONTAINER_NAME"; then
    echo "Container is running"
else
    echo "Container failed to start"
    docker logs "$CONTAINER_NAME"
    exit 1
fi
EOF

echo "App deployed — http://$APP_SERVER_HOST"
