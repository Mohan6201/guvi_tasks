#!/bin/bash

# ApplicationStart hook for CodeDeploy
# This script starts the application

set -e

echo "Starting ApplicationStart hook..."

# Scale up the deployment
echo "Scaling up deployment to 3 replicas..."
kubectl scale deployment brain-tasks-app --replicas=3 -n brain-tasks

# Wait for all pods to be ready
echo "Waiting for all pods to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/brain-tasks-app -n brain-tasks

# Get the load balancer URL
echo "Getting Load Balancer URL..."
LOAD_BALANCER_URL=$(kubectl get service brain-tasks-app-service -n brain-tasks -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -n "$LOAD_BALANCER_URL" ]; then
    echo "Application is accessible at: http://$LOAD_BALANCER_URL"
else
    echo "Load balancer is still being provisioned..."
fi

# Show pod status
echo "Pod status:"
kubectl get pods -n brain-tasks -l app=brain-tasks-app

echo "ApplicationStart hook completed successfully!"
