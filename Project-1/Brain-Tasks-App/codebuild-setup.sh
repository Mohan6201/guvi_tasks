#!/bin/bash
# ============================================================
# CodeBuild Setup - creates TWO projects, both driven by .env:
#   1. $CODEBUILD_BUILD_PROJECT  - builds the Docker image, pushes to ECR
#      (runs buildspec.yml, needs privileged mode for `docker build`)
#   2. $CODEBUILD_DEPLOY_PROJECT - renders k8s manifests and kubectl-applies
#      them to EKS (runs buildspec-deploy.yml)
#
# Both projects get their environment variables injected straight from
# .env, so buildspec.yml / buildspec-deploy.yml never hardcode anything -
# they just reference $AWS_REGION, $ECR_REPOSITORY_NAME, etc. as normal
# CodeBuild environment variables.
#
# Requires iam-setup.sh to have been run first.
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$SCRIPT_DIR/.env" ]; then
  echo "ERROR: .env not found. Run: cp .env.example .env   (then fill in values)" >&2
  exit 1
fi
set -a
source "$SCRIPT_DIR/.env"
set +a

SERVICE_ROLE_ARN=$(aws iam get-role --role-name "$CODEBUILD_SERVICE_ROLE_NAME" --query Role.Arn --output text)

# Build the --environment-variables JSON array from .env values that the
# buildspecs actually need at runtime.
ENV_VARS_JSON="[{name=AWS_REGION,value=${AWS_REGION}},{name=AWS_ACCOUNT_ID,value=${AWS_ACCOUNT_ID}},{name=APP_NAME,value=${APP_NAME}},{name=CONTAINER_PORT,value=${CONTAINER_PORT}},{name=ECR_REPOSITORY_NAME,value=${ECR_REPOSITORY_NAME}},{name=IMAGE_TAG,value=${IMAGE_TAG}},{name=EKS_CLUSTER_NAME,value=${EKS_CLUSTER_NAME}},{name=K8S_NAMESPACE,value=${K8S_NAMESPACE}},{name=SOURCE_DIR,value=${SOURCE_DIR}}]"

echo "== Note: standalone GitHub source needs a one-time token import =="
echo "If this project will pull directly from GitHub (outside of CodePipeline),"
echo "run this once (token is never stored in .env or this repo):"
echo '  aws codebuild import-source-credentials --server-type GITHUB \'
echo '    --auth-type PERSONAL_ACCESS_TOKEN --token <your-github-PAT>'
echo "(Not required when the project is only invoked as a CodePipeline Build/Deploy"
echo " action - the pipeline hands it already-checked-out source instead.)"
echo ""

create_or_update_project() {
  local project_name=$1
  local buildspec_file=$2
  local privileged=$3

  if aws codebuild batch-get-projects --names "$project_name" --region "$AWS_REGION" \
      --query "projects[0].name" --output text 2>/dev/null | grep -q "$project_name"; then
    echo "-> Project $project_name exists, updating..."
    aws codebuild update-project \
      --name "$project_name" \
      --source type=GITHUB,location="${GITHUB_REPO_URL}",buildspec="${SOURCE_DIR:+$SOURCE_DIR/}${buildspec_file}",gitCloneDepth=1 \
      --source-version "$GITHUB_BRANCH" \
      --artifacts type=NO_ARTIFACTS \
      --environment type=LINUX_CONTAINER,image="${CODEBUILD_IMAGE}",computeType=BUILD_GENERAL1_SMALL,privilegedMode=${privileged},environmentVariables="${ENV_VARS_JSON}" \
      --service-role "$SERVICE_ROLE_ARN" \
      --region "$AWS_REGION" >/dev/null
  else
    echo "-> Creating project $project_name..."
    aws codebuild create-project \
      --name "$project_name" \
      --source type=GITHUB,location="${GITHUB_REPO_URL}",buildspec="${SOURCE_DIR:+$SOURCE_DIR/}${buildspec_file}",gitCloneDepth=1 \
      --source-version "$GITHUB_BRANCH" \
      --artifacts type=NO_ARTIFACTS \
      --environment type=LINUX_CONTAINER,image="${CODEBUILD_IMAGE}",computeType=BUILD_GENERAL1_SMALL,privilegedMode=${privileged},environmentVariables="${ENV_VARS_JSON}" \
      --service-role "$SERVICE_ROLE_ARN" \
      --timeout-in-minutes 20 \
      --logs-config cloudWatchLogs="{status=ENABLED,groupName=${CLOUDWATCH_LOG_GROUP}}" \
      --region "$AWS_REGION" >/dev/null
  fi
  echo "   done."
}

echo "== Creating/updating build project (privileged=true for docker build) =="
create_or_update_project "$CODEBUILD_BUILD_PROJECT" "buildspec.yml" "true"

echo "== Creating/updating deploy project (kubectl apply to EKS) =="
create_or_update_project "$CODEBUILD_DEPLOY_PROJECT" "buildspec-deploy.yml" "false"

echo ""
echo "CodeBuild setup complete."
echo "Manual test run:  aws codebuild start-build --project-name ${CODEBUILD_BUILD_PROJECT} --region ${AWS_REGION}"
echo "CloudWatch logs:  ${CLOUDWATCH_LOG_GROUP}"
