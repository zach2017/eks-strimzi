output "prometheus_endpoint" {
  description = "Prometheus service endpoint"
  value       = var.enable_prometheus ? "kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090" : null
}

output "grafana_endpoint" {
  description = "Grafana service endpoint"
  value       = var.enable_grafana ? "kube-prometheus-stack-grafana.monitoring.svc.cluster.local:80" : null
}

output "monitoring_namespace" {
  description = "Monitoring namespace"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}
