variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for tagging and naming"
  type        = string
  default     = "eks-strimzi"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.29"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "node_groups" {
  description = "EKS node group configurations"
  type = map(object({
    desired_size   = number
    min_size       = number
    max_size       = number
    instance_types = list(string)
    disk_size      = number
    labels         = map(string)
    taints         = list(object({ key = string, value = string, effect = string }))
  }))

  default = {
    general = {
      desired_size   = 3
      min_size       = 3
      max_size       = 10
      instance_types = ["t3.large"]
      disk_size      = 50
      labels = {
        workload = "general"
      }
      taints = []
    }
  }
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
  default = {
    "auto.create.topics.enable"  = "false"
    "default.replication.factor" = "3"
    "min.insync.replicas"        = "2"
    "log.retention.hours"        = "168"
    "log.cleanup.policy"         = "delete"
  }
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

variable "enable_prometheus" {
  description = "Enable Prometheus monitoring"
  type        = bool
  default     = true
}

variable "enable_grafana" {
  description = "Enable Grafana visualization"
  type        = bool
  default     = true
}

variable "enable_loki" {
  description = "Enable Loki logging"
  type        = bool
  default     = false
}
