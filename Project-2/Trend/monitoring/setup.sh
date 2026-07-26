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

# Auto-provision the Prometheus datasource and the verified cluster
# dashboard via Grafana's API, instead of manual UI clicking. The
# dashboard JSON only has confirmed-working queries (see
# trend-cluster-health-dashboard.json comments in git history for why:
# community dashboard 315 was tried first and mostly showed N/A - its
# queries assume Docker's old cgroup/container naming, which containerd
# on modern EKS nodes never sets).
echo ""
echo "Waiting for Grafana's LoadBalancer DNS to be reachable..."
for i in $(seq 1 30); do
  curl -sf "http://$GRAFANA_URL:3000/api/health" > /dev/null 2>&1 && break
  sleep 10
done

echo "Adding Prometheus datasource..."
DS_RESPONSE=$(curl -s -u admin:admin123 -X POST "http://$GRAFANA_URL:3000/api/datasources" \
  -H "Content-Type: application/json" \
  -d '{"name":"Prometheus","type":"prometheus","url":"http://prometheus-service:9090","access":"proxy","isDefault":true}')
DS_UID=$(echo "$DS_RESPONSE" | grep -oE '"uid":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$DS_UID" ]; then
  echo "Datasource may already exist, looking it up..."
  DS_UID=$(curl -s -u admin:admin123 "http://$GRAFANA_URL:3000/api/datasources/name/Prometheus" | grep -oE '"uid":"[^"]*"' | head -1 | cut -d'"' -f4)
fi

echo "Importing Trend Cluster Health dashboard..."
sed "s/PROM_DATASOURCE_UID/${DS_UID}/g" monitoring/trend-cluster-health-dashboard.json > /tmp/dash-import.json
curl -s -u admin:admin123 -X POST "http://$GRAFANA_URL:3000/api/dashboards/db" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/dash-import.json
rm -f /tmp/dash-import.json

echo ""
echo "Dashboard ready: http://$GRAFANA_URL:3000/d/trend-cluster-health"
