#!/bin/bash
# ============================================================
# CodePipeline Setup - wires Source (GitHub) -> Build (CodeBuild) ->
# Deploy (CodeBuild running kubectl) into one pipeline, entirely from
# .env values.
#
# Prerequisites:
#   1. iam-setup.sh, ecr-setup.sh, eks-setup.sh, codebuild-setup.sh
#      already run.
#   2. A GitHub connection created once via:
#      AWS Console -> Developer Tools -> Settings -> Connections ->
#      Create connection -> GitHub -> authorize -> wait for status
#      "Available" -> copy its ARN into CODESTAR_CONNECTION_ARN in .env.
#      (This single step cannot be done via CLI - it requires the
#      GitHub OAuth handshake in a browser.)
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

if [ -z "$CODESTAR_CONNECTION_ARN" ]; then
  echo "ERROR: CODESTAR_CONNECTION_ARN is empty in .env." >&2
  echo "Create the GitHub connection in the console first (see script header), then set it." >&2
  exit 1
fi

PIPELINE_ROLE_ARN=$(aws iam get-role --role-name "$CODEPIPELINE_SERVICE_ROLE_NAME" --query Role.Arn --output text)

echo "== Ensuring artifact bucket exists =="
if aws s3api head-bucket --bucket "$CODEPIPELINE_ARTIFACT_BUCKET" 2>/dev/null; then
  echo "-> Bucket $CODEPIPELINE_ARTIFACT_BUCKET already exists."
else
  if [ "$AWS_REGION" == "us-east-1" ]; then
    aws s3api create-bucket --bucket "$CODEPIPELINE_ARTIFACT_BUCKET" --region "$AWS_REGION"
  else
    aws s3api create-bucket --bucket "$CODEPIPELINE_ARTIFACT_BUCKET" --region "$AWS_REGION" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION"
  fi
  aws s3api put-bucket-encryption --bucket "$CODEPIPELINE_ARTIFACT_BUCKET" \
    --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
fi

PIPELINE_JSON=$(cat <<EOF
{
  "pipeline": {
    "name": "${CODEPIPELINE_NAME}",
    "roleArn": "${PIPELINE_ROLE_ARN}",
    "artifactStore": {
      "type": "S3",
      "location": "${CODEPIPELINE_ARTIFACT_BUCKET}"
    },
    "stages": [
      {
        "name": "Source",
        "actions": [
          {
            "name": "GitHub_Source",
            "actionTypeId": {
              "category": "Source",
              "owner": "AWS",
              "provider": "CodeStarSourceConnection",
              "version": "1"
            },
            "outputArtifacts": [{ "name": "SourceOutput" }],
            "configuration": {
              "ConnectionArn": "${CODESTAR_CONNECTION_ARN}",
              "FullRepositoryId": "$(echo "$GITHUB_REPO_URL" | sed -E 's#https://github.com/##; s#\.git$##')",
              "BranchName": "${GITHUB_BRANCH}"
            }
          }
        ]
      },
      {
        "name": "Build",
        "actions": [
          {
            "name": "Docker_Build_Push_ECR",
            "actionTypeId": {
              "category": "Build",
              "owner": "AWS",
              "provider": "CodeBuild",
              "version": "1"
            },
            "inputArtifacts": [{ "name": "SourceOutput" }],
            "outputArtifacts": [{ "name": "BuildOutput" }],
            "configuration": { "ProjectName": "${CODEBUILD_BUILD_PROJECT}" }
          }
        ]
      },
      {
        "name": "Deploy",
        "actions": [
          {
            "name": "Deploy_To_EKS",
            "actionTypeId": {
              "category": "Build",
              "owner": "AWS",
              "provider": "CodeBuild",
              "version": "1"
            },
            "inputArtifacts": [{ "name": "BuildOutput" }],
            "configuration": { "ProjectName": "${CODEBUILD_DEPLOY_PROJECT}" }
          }
        ]
      }
    ]
  }
}
EOF
)

echo "$PIPELINE_JSON" > /tmp/pipeline.json

if aws codepipeline get-pipeline --name "$CODEPIPELINE_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "== Pipeline $CODEPIPELINE_NAME exists, updating =="
  aws codepipeline update-pipeline --cli-input-json "$PIPELINE_JSON" --region "$AWS_REGION" >/dev/null
else
  echo "== Creating pipeline $CODEPIPELINE_NAME =="
  aws codepipeline create-pipeline --cli-input-json "$PIPELINE_JSON" --region "$AWS_REGION" >/dev/null
fi

echo ""
echo "CodePipeline setup complete: Source(GitHub) -> Build(CodeBuild) -> Deploy(CodeBuild/kubectl->EKS)"
echo "Trigger manually: aws codepipeline start-pipeline-execution --name ${CODEPIPELINE_NAME} --region ${AWS_REGION}"
echo "Console:          https://${AWS_REGION}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${CODEPIPELINE_NAME}/view"
