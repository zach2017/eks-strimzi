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

variable "enable_prometheus" {
  description = "Enable Prometheus"
  type        = bool
  default     = true
}

variable "enable_grafana" {
  description = "Enable Grafana"
  type        = bool
  default     = true
}

variable "enable_loki" {
  description = "Enable Loki for logging"
  type        = bool
  default     = false
}

variable "prometheus_retention" {
  description = "Prometheus data retention"
  type        = string
  default     = "15d"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "admin123"
}
