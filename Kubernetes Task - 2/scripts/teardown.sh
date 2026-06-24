#!/bin/bash
set -e

echo "Deleting Kubernetes resources..."
kubectl delete -f ../k8s/service.yaml --ignore-not-found
kubectl delete -f ../k8s/deployment.yaml --ignore-not-found

echo "Deleting EKS cluster: $CLUSTER_NAME ..."
eksctl delete cluster --name "$CLUSTER_NAME" --region "$AWS_DEFAULT_REGION"

echo "Cluster deleted successfully."
