aws_region       = "us-east-1"
project_name     = "eks-strimzi"
environment      = "dev"
cluster_name     = "eks-strimzi-dev"
kubernetes_version = "1.29"

vpc_cidr             = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

node_groups = {
  general = {
    desired_size   = 2
    min_size       = 2
    max_size       = 5
    instance_types = ["t3.large"]
    disk_size      = 50
    labels = {
      workload = "general"
    }
    taints = []
  }
}

strimzi_version = "0.39.0"
kafka_version   = "3.7.0"

kafka_config = {
  "auto.create.topics.enable"       = "false"
  "default.replication.factor"      = "1"
  "min.insync.replicas"             = "1"
  "log.retention.hours"             = "24"
  "log.cleanup.policy"              = "delete"
}

zookeeper_replicas = 1
kafka_brokers      = 1

enable_prometheus = true
enable_grafana    = true
enable_loki       = false
