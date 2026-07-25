#!/bin/bash
# ============================================================
# EKS Cluster Setup - creates the cluster + managed node group.
# Requires iam-setup.sh to have been run first (needs
# EKSClusterRole / EKSNodeRole to exist).
#
# Uses EKS "access entries" (authenticationMode=API_AND_CONFIG_MAP)
# so the node role and your own IAM identity get cluster access
# without hand-editing the aws-auth ConfigMap.
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

echo "== EKS setup: cluster '${EKS_CLUSTER_NAME}' in ${AWS_REGION} =="

CLUSTER_ROLE_ARN=$(aws iam get-role --role-name "$EKS_CLUSTER_ROLE_NAME" --query Role.Arn --output text)
NODE_ROLE_ARN=$(aws iam get-role --role-name "$EKS_NODE_ROLE_NAME" --query Role.Arn --output text)
CALLER_ARN=$(aws sts get-caller-identity --query Arn --output text)

# Default VPC subnets (2 AZs) - fine for a lab/assessment cluster.
SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters Name=default-for-az,Values=true \
  --query 'Subnets[0:2].SubnetId' --output text --region "$AWS_REGION" | tr '\t' ',')
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values=default \
  --query 'SecurityGroups[0].GroupId' --output text --region "$AWS_REGION")

if [ -z "$SUBNET_IDS" ] || [ "$SUBNET_IDS" == "None" ]; then
  echo "ERROR: could not find default subnets in ${AWS_REGION}. Pass explicit subnet IDs instead." >&2
  exit 1
fi

echo "Cluster role: $CLUSTER_ROLE_ARN"
echo "Subnets:      $SUBNET_IDS"
echo "Security grp: $SECURITY_GROUP_ID"

if aws eks describe-cluster --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "Cluster $EKS_CLUSTER_NAME already exists, skipping creation."
else
  echo "Creating EKS cluster (this takes ~10-15 minutes)..."
  aws eks create-cluster \
    --name "$EKS_CLUSTER_NAME" \
    --region "$AWS_REGION" \
    --kubernetes-version "$EKS_K8S_VERSION" \
    --role-arn "$CLUSTER_ROLE_ARN" \
    --resources-vpc-config subnetIds="$SUBNET_IDS",securityGroupIds="$SECURITY_GROUP_ID" \
    --access-config authenticationMode=API_AND_CONFIG_MAP

  echo "Waiting for cluster to become ACTIVE..."
  aws eks wait cluster-active --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION"
fi

echo "Updating local kubeconfig..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME"

echo "Granting your IAM identity cluster-admin access via an EKS access entry..."
aws eks create-access-entry \
  --cluster-name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" \
  --principal-arn "$CALLER_ARN" --type STANDARD >/dev/null 2>&1 || true
aws eks associate-access-policy \
  --cluster-name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" \
  --principal-arn "$CALLER_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster >/dev/null 2>&1 || true

echo "Granting the CodeBuild deploy role cluster access too..."
CODEBUILD_ROLE_ARN=$(aws iam get-role --role-name "$CODEBUILD_SERVICE_ROLE_NAME" --query Role.Arn --output text 2>/dev/null || echo "")
if [ -n "$CODEBUILD_ROLE_ARN" ]; then
  aws eks create-access-entry \
    --cluster-name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" \
    --principal-arn "$CODEBUILD_ROLE_ARN" --type STANDARD >/dev/null 2>&1 || true
  aws eks associate-access-policy \
    --cluster-name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" \
    --principal-arn "$CODEBUILD_ROLE_ARN" \
    --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
    --access-scope type=cluster >/dev/null 2>&1 || true
fi

if aws eks describe-nodegroup --cluster-name "$EKS_CLUSTER_NAME" --nodegroup-name "$EKS_NODE_GROUP_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "Node group $EKS_NODE_GROUP_NAME already exists, skipping creation."
else
  echo "Creating managed node group (this takes ~5-10 minutes)..."
  aws eks create-nodegroup \
    --cluster-name "$EKS_CLUSTER_NAME" \
    --nodegroup-name "$EKS_NODE_GROUP_NAME" \
    --region "$AWS_REGION" \
    --scaling-config desiredSize="$EKS_DESIRED_NODES",minSize="$EKS_MIN_NODES",maxSize="$EKS_MAX_NODES" \
    --subnets $(echo "$SUBNET_IDS" | tr ',' ' ') \
    --instance-types "$EKS_NODE_TYPE" \
    --ami-type AL2_x86_64 \
    --node-role "$NODE_ROLE_ARN"

  echo "Waiting for node group to become ACTIVE..."
  aws eks wait nodegroup-active --cluster-name "$EKS_CLUSTER_NAME" --nodegroup-name "$EKS_NODE_GROUP_NAME" --region "$AWS_REGION"
fi

echo ""
echo "== EKS cluster verification =="
kubectl get nodes
kubectl cluster-info

echo ""
echo "EKS setup complete. Cluster: $EKS_CLUSTER_NAME  Region: $AWS_REGION"
