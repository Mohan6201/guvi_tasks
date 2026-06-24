#!/bin/bash
set -e

# -------------------------------------------------------------------
# 1. Check prerequisites
# -------------------------------------------------------------------

echo "Checking prerequisites..."

for tool in aws eksctl kubectl envsubst; do
  if ! command -v $tool &>/dev/null; then
    echo "ERROR: '$tool' is not installed. Please install it and re-run."
    exit 1
  fi
done

echo "All prerequisites found."

# -------------------------------------------------------------------
# 2. Verify required environment variables
# -------------------------------------------------------------------

REQUIRED_VARS=(
  AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY
  AWS_DEFAULT_REGION
  CLUSTER_NAME
  K8S_VERSION
  NODE_INSTANCE_TYPE
  NODE_DESIRED
  NODE_MIN
  NODE_MAX
)

for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var}" ]; then
    echo "ERROR: Environment variable '$var' is not set. Check your .env file."
    exit 1
  fi
done

echo "All environment variables are set."

# -------------------------------------------------------------------
# 3. Create EKS cluster using eksctl
# -------------------------------------------------------------------

echo "Creating EKS cluster: $CLUSTER_NAME in $AWS_DEFAULT_REGION ..."

envsubst < ../cluster/eks-cluster.yaml | eksctl create cluster -f -

echo "EKS cluster created successfully."

# -------------------------------------------------------------------
# 4. Update kubeconfig
# -------------------------------------------------------------------

echo "Updating kubeconfig..."

aws eks update-kubeconfig --region "$AWS_DEFAULT_REGION" --name "$CLUSTER_NAME"

echo "Kubeconfig updated. Current context:"
kubectl config current-context

# -------------------------------------------------------------------
# 5. Verify nodes are ready
# -------------------------------------------------------------------

echo "Waiting for nodes to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s
kubectl get nodes

# -------------------------------------------------------------------
# 6. Deploy Nginx
# -------------------------------------------------------------------

echo "Deploying Nginx..."

kubectl apply -f ../k8s/deployment.yaml
kubectl apply -f ../k8s/service.yaml

echo "Waiting for deployment to be available..."
kubectl rollout status deployment/nginx-deployment --timeout=120s

# -------------------------------------------------------------------
# 7. Get the external LoadBalancer URL
# -------------------------------------------------------------------

echo "Waiting for LoadBalancer external IP to be assigned (this may take 2-3 minutes)..."

for i in {1..30}; do
  EXTERNAL_URL=$(kubectl get svc nginx-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
  if [ -n "$EXTERNAL_URL" ]; then
    break
  fi
  echo "  Still waiting... ($i/30)"
  sleep 10
done

if [ -z "$EXTERNAL_URL" ]; then
  echo "LoadBalancer URL not yet assigned. Run this to check later:"
  echo "  kubectl get svc nginx-service"
else
  echo ""
  echo "=========================================="
  echo "  Nginx is live at: http://$EXTERNAL_URL"
  echo "=========================================="
fi

kubectl get all
