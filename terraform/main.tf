terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }

  # Uncomment and configure for remote state management
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "eks-strimzi/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      CreatedAt   = timestamp()
    }
  }
}

# Get current AWS account ID and caller identity
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# EKS Cluster Module
module "eks_cluster" {
  source = "./modules/eks-cluster"

  cluster_name           = var.cluster_name
  cluster_version        = var.kubernetes_version
  region                 = var.aws_region
  vpc_cidr               = var.vpc_cidr
  availability_zones     = data.aws_availability_zones.available.names
  private_subnet_cidrs   = var.private_subnet_cidrs
  public_subnet_cidrs    = var.public_subnet_cidrs
  
  node_groups = var.node_groups
  
  enable_irsa            = true
  enable_cluster_logging = true

  tags = local.common_tags
}

# Strimzi Module
module "strimzi" {
  source = "./modules/strimzi"

  cluster_name       = module.eks_cluster.cluster_name
  cluster_endpoint   = module.eks_cluster.cluster_endpoint
  cluster_ca         = module.eks_cluster.cluster_ca
  strimzi_version    = var.strimzi_version
  kafka_version      = var.kafka_version
  
  kafka_config       = var.kafka_config
  zookeeper_replicas = var.zookeeper_replicas
  kafka_brokers      = var.kafka_brokers

  depends_on = [module.eks_cluster]
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"

  cluster_name     = module.eks_cluster.cluster_name
  cluster_endpoint = module.eks_cluster.cluster_endpoint
  cluster_ca       = module.eks_cluster.cluster_ca
  
  enable_prometheus = var.enable_prometheus
  enable_grafana    = var.enable_grafana
  enable_loki       = var.enable_loki

  depends_on = [module.eks_cluster]
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    CreatedBy   = "Terraform"
  }
}
