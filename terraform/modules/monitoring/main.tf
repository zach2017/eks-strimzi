terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

# Create monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

# Add Prometheus community Helm repository
resource "helm_repository" "prometheus_community" {
  count = var.enable_prometheus ? 1 : 0
  name  = "prometheus-community"
  url   = "https://prometheus-community.github.io/helm-charts"
}

# Install kube-prometheus-stack
resource "helm_release" "kube_prometheus_stack" {
  count            = var.enable_prometheus ? 1 : 0
  name             = "kube-prometheus-stack"
  repository       = helm_repository.prometheus_community[0].name
  chart            = "kube-prometheus-stack"
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  create_namespace = false

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = var.prometheus_retention
  }

  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  set {
    name  = "grafana.enabled"
    value = var.enable_grafana ? "true" : "false"
  }

  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  depends_on = [helm_repository.prometheus_community]
}

# ServiceMonitor for Kafka/Strimzi metrics
resource "kubernetes_manifest" "kafka_service_monitor" {
  count = var.enable_prometheus ? 1 : 0
  
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "kafka-cluster"
      namespace = "kafka"
    }
    spec = {
      selector = {
        matchLabels = {
          "strimzi.io/cluster" = "kafka-cluster"
          "strimzi.io/kind"    = "Kafka"
        }
      }
      endpoints = [
        {
          port   = "tcp-prometheus"
          interval = "30s"
        }
      ]
    }
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

# Add Grafana repository
resource "helm_repository" "grafana" {
  count = var.enable_grafana && var.enable_loki ? 1 : 0
  name  = "grafana"
  url   = "https://grafana.github.io/helm-charts"
}

# Install Loki
resource "helm_release" "loki_stack" {
  count            = var.enable_loki ? 1 : 0
  name             = "loki-stack"
  repository       = helm_repository.grafana[0].name
  chart            = "loki-stack"
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  create_namespace = false

  set {
    name  = "loki.enabled"
    value = "true"
  }

  set {
    name  = "promtail.enabled"
    value = "true"
  }
}
