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

# Note: Kubernetes and Helm providers are configured in parent module (main.tf)

# Create Kafka namespace
resource "kubernetes_namespace" "kafka" {
  metadata {
    name = "kafka"
  }
}

# Install Strimzi operator using Helm
resource "helm_release" "strimzi" {
  name             = "strimzi"
  repository       = "https://strimzi.io/charts"
  chart            = "strimzi-kafka-operator"
  namespace        = kubernetes_namespace.kafka.metadata[0].name
  version          = var.strimzi_version
  create_namespace = false

  set {
    name  = "watchAnyNamespace"
    value = "true"
  }
}

# Deploy Kafka cluster
resource "kubernetes_manifest" "kafka_cluster" {
  manifest = {
    apiVersion = "kafka.strimzi.io/v1beta2"
    kind       = "Kafka"
    metadata = {
      name      = "kafka-cluster"
      namespace = kubernetes_namespace.kafka.metadata[0].name
    }
    spec = {
      kafka = {
        version  = var.kafka_version
        replicas = var.kafka_brokers

        listeners = [
          {
            name = "plain"
            port = 9092
            type = "internal"
            tls  = false
          },
          {
            name = "tls"
            port = 9093
            type = "internal"
            tls  = true
          },
          {
            name = "external"
            port = 9094
            type = "nodeport"
            tls  = false
          }
        ]

        config = var.kafka_config

        storage = {
          type  = "persistent-claim"
          size  = var.kafka_storage_size
          class = "ebs-sc"
        }

        resources = {
          limits = {
            memory = var.kafka_memory_limit
          }
          requests = {
            memory = var.kafka_memory_request
            cpu    = "500m"
          }
        }
      }

      zookeeper = {
        replicas = var.zookeeper_replicas

        storage = {
          type  = "persistent-claim"
          size  = var.zookeeper_storage_size
          class = "ebs-sc"
        }

        resources = {
          limits = {
            memory = "512Mi"
          }
          requests = {
            memory = "256Mi"
            cpu    = "100m"
          }
        }
      }

      entityOperator = {
        topicOperator = {}
        userOperator  = {}
      }
    }
  }

  depends_on = [
    helm_release.strimzi,
    kubernetes_storage_class.ebs
  ]
}

# Create storage class for EBS
resource "kubernetes_storage_class" "ebs" {
  metadata {
    name = "ebs-sc"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true

  parameters = {
    type        = "gp3"
    iops        = "3000"
    throughput  = "125"
    "encrypted" = "true"
  }
}

# Create example KafkaTopic
resource "kubernetes_manifest" "example_topic" {
  manifest = {
    apiVersion = "kafka.strimzi.io/v1beta2"
    kind       = "KafkaTopic"
    metadata = {
      name      = "example-topic"
      namespace = kubernetes_namespace.kafka.metadata[0].name
      labels = {
        "strimzi.io/cluster" = "kafka-cluster"
      }
    }
    spec = {
      partitions        = 3
      replicationFactor = min(3, var.kafka_brokers)
      config = {
        "retention.ms"   = "604800000"
        "cleanup.policy" = "delete"
      }
    }
  }

  depends_on = [kubernetes_manifest.kafka_cluster]
}
