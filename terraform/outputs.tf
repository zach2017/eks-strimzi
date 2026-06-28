output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks_cluster.cluster_id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes server version for the cluster"
  value       = module.eks_cluster.cluster_version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks_cluster.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = module.eks_cluster.node_security_group_id
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks_cluster.cluster_name}"
}

output "kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers"
  value       = module.strimzi.kafka_bootstrap_servers
}

output "kafka_cluster_name" {
  description = "Kafka cluster name in Kubernetes"
  value       = module.strimzi.kafka_cluster_name
}

output "prometheus_endpoint" {
  description = "Prometheus service endpoint"
  value       = module.monitoring.prometheus_endpoint
  sensitive   = false
}

output "grafana_endpoint" {
  description = "Grafana service endpoint"
  value       = module.monitoring.grafana_endpoint
  sensitive   = false
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}
