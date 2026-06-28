output "kafka_namespace" {
  description = "Kubernetes namespace for Kafka"
  value       = kubernetes_namespace.kafka.metadata[0].name
}

output "kafka_cluster_name" {
  description = "Kafka cluster name"
  value       = kubernetes_manifest.kafka_cluster.manifest.metadata.name
}

output "kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers"
  value       = "kafka-cluster-kafka-bootstrap.${kubernetes_namespace.kafka.metadata[0].name}.svc.cluster.local:9092"
}

output "kafka_bootstrap_servers_tls" {
  description = "Kafka bootstrap servers (TLS)"
  value       = "kafka-cluster-kafka-bootstrap.${kubernetes_namespace.kafka.metadata[0].name}.svc.cluster.local:9093"
}

output "strimzi_release_name" {
  description = "Helm release name for Strimzi"
  value       = helm_release.strimzi.name
}

output "strimzi_version" {
  description = "Installed Strimzi version"
  value       = helm_release.strimzi.version
}
