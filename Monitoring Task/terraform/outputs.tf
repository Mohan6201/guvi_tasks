output "instance_public_ip" {
  description = "Public IP of the monitoring server"
  value       = aws_instance.monitoring_server.public_ip
}

output "prometheus_url" {
  description = "URL to access Prometheus"
  value       = "http://${aws_instance.monitoring_server.public_ip}:9090"
}

output "grafana_url" {
  description = "URL to access Grafana"
  value       = "http://${aws_instance.monitoring_server.public_ip}:3000"
}

output "node_exporter_url" {
  description = "URL to access Node Exporter metrics"
  value       = "http://${aws_instance.monitoring_server.public_ip}:9100/metrics"
}
