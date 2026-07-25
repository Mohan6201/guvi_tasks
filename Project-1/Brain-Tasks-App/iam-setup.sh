#!/bin/bash
# ============================================================
# IAM Setup - creates the service roles every other script assumes
# already exist (EKSClusterRole, EKSNodeRole, CodeBuildServiceRole,
# CodePipelineServiceRole). Run this FIRST, before ecr-setup.sh,
# eks-setup.sh or codebuild-setup.sh.
#
# All role names are read from .env - nothing is hardcoded here.
# Idempotent: safe to re-run, existing roles/attachments are skipped.
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

echo "== IAM setup using account ${AWS_ACCOUNT_ID} in ${AWS_REGION} =="

create_role() {
  local role_name=$1
  local trust_service=$2
  local policy_arns=$3

  if aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
    echo "-> Role $role_name already exists, skipping creation."
  else
    echo "-> Creating role $role_name (trusted entity: $trust_service)..."
    local trust_doc
    trust_doc=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "${trust_service}" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
)
    aws iam create-role \
      --role-name "$role_name" \
      --assume-role-policy-document "$trust_doc" \
      --region "$AWS_REGION" >/dev/null
  fi

  IFS=',' read -ra ARNS <<< "$policy_arns"
  for arn in "${ARNS[@]}"; do
    echo "   attaching $arn"
    aws iam attach-role-policy --role-name "$role_name" --policy-arn "$arn" >/dev/null 2>&1 || true
  done
}

# 1. EKS control-plane role
create_role "$EKS_CLUSTER_ROLE_NAME" "eks.amazonaws.com" \
  "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"

# 2. EKS worker node role
create_role "$EKS_NODE_ROLE_NAME" "ec2.amazonaws.com" \
  "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy,arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy,arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"

# 3. CodeBuild service role (build + deploy projects share this)
create_role "$CODEBUILD_SERVICE_ROLE_NAME" "codebuild.amazonaws.com" \
  "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser,arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"

# CodeBuild deploy project also needs to call eks:DescribeCluster / update kubeconfig
echo "-> Attaching inline EKS describe policy to $CODEBUILD_SERVICE_ROLE_NAME..."
EKS_DESCRIBE_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["eks:DescribeCluster", "eks:ListClusters"],
      "Resource": "*"
    }
  ]
}
EOF
)
aws iam put-role-policy \
  --role-name "$CODEBUILD_SERVICE_ROLE_NAME" \
  --policy-name "EKSDescribeAccess" \
  --policy-document "$EKS_DESCRIBE_POLICY" >/dev/null

# 4. CodePipeline service role
create_role "$CODEPIPELINE_SERVICE_ROLE_NAME" "codepipeline.amazonaws.com" \
  "arn:aws:iam::aws:policy/AWSCodeBuildAdminAccess,arn:aws:iam::aws:policy/AmazonS3FullAccess,arn:aws:iam::aws:policy/AWSCodeStarFullAccess"

echo ""
echo "== IAM setup complete =="
echo "EKS cluster role ARN:   $(aws iam get-role --role-name "$EKS_CLUSTER_ROLE_NAME" --query Role.Arn --output text)"
echo "EKS node role ARN:      $(aws iam get-role --role-name "$EKS_NODE_ROLE_NAME" --query Role.Arn --output text)"
echo "CodeBuild role ARN:     $(aws iam get-role --role-name "$CODEBUILD_SERVICE_ROLE_NAME" --query Role.Arn --output text)"
echo "CodePipeline role ARN:  $(aws iam get-role --role-name "$CODEPIPELINE_SERVICE_ROLE_NAME" --query Role.Arn --output text)"
echo ""
echo "NOTE: after EKS cluster creation, the node role and your caller identity"
echo "need to be added to the cluster's aws-auth ConfigMap (eks-setup.sh handles this)."
