aws_region       = "us-east-1"
project_name     = "eks-strimzi"
environment      = "prod"
cluster_name     = "eks-strimzi-prod"
kubernetes_version = "1.29"

vpc_cidr             = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

node_groups = {
  general = {
    desired_size   = 3
    min_size       = 3
    max_size       = 20
    instance_types = ["t3.xlarge"]
    disk_size      = 100
    labels = {
      workload = "general"
    }
    taints = []
  }
  kafka = {
    desired_size   = 3
    min_size       = 3
    max_size       = 10
    instance_types = ["m5.2xlarge"]
    disk_size      = 200
    labels = {
      workload = "kafka"
    }
    taints = [
      {
        key    = "kafka"
        value  = "true"
        effect = "NoSchedule"
      }
    ]
  }
}

strimzi_version = "0.39.0"
kafka_version   = "3.7.0"

kafka_config = {
  "auto.create.topics.enable"       = "false"
  "default.replication.factor"      = "3"
  "min.insync.replicas"             = "2"
  "log.retention.hours"             = "168"
  "log.cleanup.policy"              = "delete"
  "compression.type"                = "snappy"
}

zookeeper_replicas = 3
kafka_brokers      = 3

enable_prometheus = true
enable_grafana    = true
enable_loki       = true
