#!/bin/bash

# Monitoring Setup Script

echo "Setting up monitoring stack..."

# kube-state-metrics (cluster object state: pod/deployment/node counts,
# status, resource requests) - official upstream manifests, includes
# its own ServiceAccount/RBAC. Prometheus scrapes it (see prometheus.yaml).
echo "Installing kube-state-metrics..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kube-state-metrics/main/examples/standard/cluster-role-binding.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kube-state-metrics/main/examples/standard/cluster-role.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kube-state-metrics/main/examples/standard/service-account.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kube-state-metrics/main/examples/standard/deployment.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kube-state-metrics/main/examples/standard/service.yaml

# Apply monitoring namespace, RBAC, config, Prometheus deployment/service
kubectl apply -f monitoring/prometheus.yaml

# Wait for Prometheus to be ready
echo "Waiting for Prometheus to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n monitoring

# Apply Grafana
kubectl apply -f monitoring/grafana.yaml

# Wait for Grafana to be ready
echo "Waiting for Grafana to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n monitoring

# Get service URLs
PROMETHEUS_URL=$(kubectl get svc prometheus-service -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
GRAFANA_URL=$(kubectl get svc grafana-service -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Monitoring setup complete!"
echo "Prometheus URL: http://$PROMETHEUS_URL:9090"
echo "Grafana URL: http://$GRAFANA_URL:3000"
echo "Grafana credentials: admin/admin123"

# Instructions for Grafana dashboard setup
echo ""
echo "To set up Grafana dashboard:"
echo "1. Login to Grafana at http://$GRAFANA_URL:3000"
echo "2. Add Prometheus as data source: http://prometheus-service:9090"
echo "3. Import Kubernetes dashboard templates"
