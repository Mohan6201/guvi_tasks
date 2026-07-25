#!/bin/bash
# ============================================================
# ECR Registry Setup - creates the repository that will store
# Docker images for the app. All values come from .env.
# ============================================================
set -e
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$SCRIPT_DIR/.env" ]; then
  echo "ERROR: .env not found. Run: cp .env.example .env   (then fill in values)" >&2
  exit 1
fi
set -a
source "$SCRIPT_DIR/.env"
set +a

echo "Setting up ECR repository '${ECR_REPOSITORY_NAME}' in ${AWS_REGION}..."

aws ecr create-repository \
  --repository-name "${ECR_REPOSITORY_NAME}" \
  --region "${AWS_REGION}" \
  --image-scanning-configuration scanOnPush=true \
  --image-tag-mutability MUTABLE \
  || echo "Repository may already exist, continuing..."

ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY_NAME}"
echo "ECR Repository URI: ${ECR_URI}"

echo "Authenticating local Docker with ECR..."
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo ""
echo "ECR setup complete."
echo "To push manually:"
echo "  docker tag ${APP_NAME}:${IMAGE_TAG} ${ECR_URI}:${IMAGE_TAG}"
echo "  docker push ${ECR_URI}:${IMAGE_TAG}"
