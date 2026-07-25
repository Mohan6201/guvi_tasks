#!/bin/bash
# ============================================================
# Manual Kubernetes Deploy - for running kubectl apply from your own
# machine (outside CodeBuild). Sources .env, builds/uses the latest
# ECR image tag, renders the k8s templates, and applies them.
#
# Requires: eks-setup.sh already run (cluster + kubeconfig ready),
# ecr-setup.sh already run (repository + image pushed).
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ ! -f "$ROOT_DIR/.env" ]; then
  echo "ERROR: .env not found. Run: cp .env.example .env   (then fill in values)" >&2
  exit 1
fi
set -a
source "$ROOT_DIR/.env"
set +a

IMAGE_URI="${1:-${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY_NAME}:${IMAGE_TAG}}"
echo "Deploying ${APP_NAME} using image: ${IMAGE_URI}"

echo "Pointing kubectl at cluster ${EKS_CLUSTER_NAME}..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME" >/dev/null

echo "Rendering manifests..."
"$SCRIPT_DIR/render.sh" "IMAGE_URI=${IMAGE_URI}"

echo "Applying namespace..."
kubectl apply -f "$SCRIPT_DIR/rendered/namespace.yaml"

echo "Creating/refreshing ECR pull secret (ECR tokens expire every 12h)..."
kubectl create secret docker-registry ecr-registry-secret \
  --docker-server="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com" \
  --docker-username=AWS \
  --docker-password="$(aws ecr get-login-password --region "$AWS_REGION")" \
  --namespace="$K8S_NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Applying deployment and service..."
kubectl apply -f "$SCRIPT_DIR/rendered/deployment.yaml"
kubectl apply -f "$SCRIPT_DIR/rendered/service.yaml"

echo "Waiting for rollout..."
kubectl rollout status "deployment/${APP_NAME}" -n "$K8S_NAMESPACE" --timeout=300s

echo ""
echo "Pods:"
kubectl get pods -n "$K8S_NAMESPACE" -l "app=${APP_NAME}"
echo ""
echo "Waiting for LoadBalancer hostname (can take a few minutes)..."
for i in $(seq 1 30); do
  LB=$(kubectl get service "${APP_NAME}-service" -n "$K8S_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  if [ -n "$LB" ]; then
    echo "Application URL: http://${LB}"
    break
  fi
  sleep 10
done

echo "Deployment complete."
