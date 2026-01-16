#!/bin/bash

# ValidateService hook for CodeDeploy
# This script validates that the service is running correctly

set -e

echo "Starting ValidateService hook..."

# Check if deployment is successful
echo "Checking deployment status..."
kubectl rollout status deployment/brain-tasks-app -n brain-tasks --timeout=60s

# Check pod health
echo "Checking pod health..."
READY_PODS=$(kubectl get deployment brain-tasks-app -n brain-tasks -o jsonpath='{.status.readyReplicas}')
DESIRED_PODS=$(kubectl get deployment brain-tasks-app -n brain-tasks -o jsonpath='{.spec.replicas}')

if [ "$READY_PODS" = "$DESIRED_PODS" ] && [ "$READY_PODS" -gt 0 ]; then
    echo "✓ All pods are ready: $READY_PODS/$DESIRED_PODS"
else
    echo "✗ Pod health check failed: $READY_PODS/$DESIRED_PODS ready"
    exit 1
fi

# Check service endpoints
echo "Checking service endpoints..."
SERVICE_ENDPOINTS=$(kubectl get endpoints brain-tasks-app-service -n brain-tasks -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w)

if [ "$SERVICE_ENDPOINTS" -gt 0 ]; then
    echo "✓ Service has $SERVICE_ENDPOINTS ready endpoints"
else
    echo "✗ No service endpoints available"
    exit 1
fi

# Check load balancer status (if applicable)
echo "Checking load balancer status..."
LOAD_BALANCER_TYPE=$(kubectl get service brain-tasks-app-service -n brain-tasks -o jsonpath='{.spec.type}')

if [ "$LOAD_BALANCER_TYPE" = "LoadBalancer" ]; then
    LB_HOSTNAME=$(kubectl get service brain-tasks-app-service -n brain-tasks -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ -n "$LB_HOSTNAME" ]; then
        echo "✓ Load balancer is provisioned: $LB_HOSTNAME"
    else
        echo "⚠ Load balancer is still being provisioned"
    fi
fi

# Show application logs for verification
echo "Recent application logs:"
kubectl logs -n brain-tasks -l app=brain-tasks-app --tail=10

echo "ValidateService hook completed successfully!"
