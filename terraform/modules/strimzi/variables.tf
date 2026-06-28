variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster endpoint"
  type        = string
}

variable "cluster_ca" {
  description = "EKS cluster CA certificate"
  type        = string
  sensitive   = true
}

variable "strimzi_version" {
  description = "Strimzi operator version"
  type        = string
  default     = "0.39.0"
}

variable "kafka_version" {
  description = "Apache Kafka version"
  type        = string
  default     = "3.7.0"
}

variable "kafka_config" {
  description = "Kafka broker configuration"
  type        = map(string)
  default     = {}
}

variable "zookeeper_replicas" {
  description = "Number of ZooKeeper replicas"
  type        = number
  default     = 3
}

variable "kafka_brokers" {
  description = "Number of Kafka brokers"
  type        = number
  default     = 3
}

variable "kafka_storage_size" {
  description = "Storage size for Kafka brokers"
  type        = string
  default     = "10Gi"
}

variable "zookeeper_storage_size" {
  description = "Storage size for ZooKeeper"
  type        = string
  default     = "2Gi"
}

variable "kafka_memory_limit" {
  description = "Memory limit for Kafka brokers"
  type        = string
  default     = "2Gi"
}

variable "kafka_memory_request" {
  description = "Memory request for Kafka brokers"
  type        = string
  default     = "1Gi"
}

variable "enable_metrics" {
  description = "Enable Prometheus metrics"
  type        = bool
  default     = true
}
