# AWS EKS + Strimzi Kafka Infrastructure

Complete infrastructure-as-code solution for deploying and managing Apache Kafka clusters on AWS EKS using Strimzi operator, with integrated monitoring, multi-language microservices, and comprehensive deployment automation.

## 🎯 Features

- **Infrastructure as Code**: Complete Terraform modules for EKS cluster provisioning
- **Strimzi Kafka**: Production-grade Kafka deployment with automatic operators
- **Multi-Environment**: Dev, staging, and production configurations
- **Monitoring**: Prometheus + Grafana integration with Kafka metrics
- **Microservices**: Example applications in Java, C#, and Python
- **Automation**: Shell/Batch scripts for deployment and management
- **CI/CD**: GitHub Actions workflows for automated deployments
- **Scalability**: Horizontal and vertical scaling capabilities
- **Security**: Network policies, RBAC, encryption, and audit logging

## 📋 Architecture

```
AWS Region
├── VPC
│   ├── Public Subnets (NAT Gateways)
│   └── Private Subnets
│       └── EKS Cluster
│           ├── Strimzi Operator
│           │   └── Kafka Cluster (3 brokers)
│           │       ├── ZooKeeper (3 replicas)
│           │       └── Entity Operator
│           ├── Monitoring Stack
│           │   ├── Prometheus
│           │   ├── Grafana
│           │   └── AlertManager
│           └── Applications
│               ├── Java Consumer
│               ├── .NET Producer
│               └── Python Monitor
```

## 🚀 Quick Start

### Prerequisites

- AWS Account with appropriate permissions
- AWS CLI v2.0+
- Terraform v1.0+
- kubectl v1.24+
- Docker (for building images)
- Python 3.9+ and Node.js 16+ (optional)

### Deploy in 5 Minutes

```bash
# 1. Clone repository
git clone <repo-url>
cd eks-strimzi

# 2. Deploy infrastructure
cd terraform
terraform init
terraform plan -var-file="environments/dev/terraform.tfvars"
terraform apply -var-file="environments/dev/terraform.tfvars"

# 3. Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name eks-strimzi-dev

# 4. Verify deployment
kubectl get pods -n kafka
./scripts/shell/k8s-manage.sh status kafka

# 5. Create a test topic
./scripts/shell/k8s-manage.sh topic-create test-topic 3 1
```

## 📁 Project Structure

```
eks-strimzi/
├── terraform/                    # Infrastructure Code
│   ├── modules/
│   │   ├── eks-cluster/         # EKS cluster module
│   │   ├── strimzi/             # Strimzi operator
│   │   └── monitoring/          # Prometheus/Grafana
│   ├── environments/            # Environment configs
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   ├── main.tf, variables.tf, outputs.tf
│
├── kubernetes/                  # K8s Manifests
│   ├── namespaces/
│   ├── strimzi-config/
│   ├── monitoring/
│   └── applications/
│
├── applications/                # Microservices
│   ├── java-kafka-consumer/    # Spring Boot + Kafka
│   ├── dotnet-kafka-producer/  # ASP.NET Core + Kafka
│   └── python-kafka-monitor/   # Python CLI tool
│
├── scripts/
│   ├── shell/                  # Bash scripts
│   │   ├── deploy.sh          # Terraform management
│   │   ├── k8s-manage.sh      # Kubernetes operations
│   │   └── aws-helper.sh      # AWS CLI wrapper
│   ├── batch/                 # Windows batch scripts
│   └── python/                # Python utilities
│
├── config/                    # Configuration files
├── docs/                      # Documentation
└── .github/workflows/         # CI/CD pipelines
```

## 🛠️ Key Capabilities

### Infrastructure Management

```bash
# Deploy to dev environment
./scripts/shell/deploy.sh dev apply

# Plan changes for production
./scripts/shell/deploy.sh prod plan

# Destroy infrastructure
./scripts/shell/deploy.sh prod destroy
```

### Kubernetes Operations

```bash
# Manage Kafka topics
./scripts/shell/k8s-manage.sh topic-create my-topic 3 2
./scripts/shell/k8s-manage.sh topic-delete my-topic
./scripts/shell/k8s-manage.sh topics

# Cluster management
./scripts/shell/k8s-manage.sh status kafka
./scripts/shell/k8s-manage.sh pods kafka
./scripts/shell/k8s-manage.sh portforward kafka 9092

# Port forward to broker
./scripts/shell/k8s-manage.sh portforward kafka 9092 9092
```

### AWS Management

```bash
# Get cluster information
./scripts/shell/aws-helper.sh cluster-info eks-strimzi-dev

# Scale node groups
./scripts/shell/aws-helper.sh scale eks-strimzi-prod general 5

# View logs
./scripts/shell/aws-helper.sh tail-logs /aws/eks/eks-strimzi-dev/cluster api-server
```

### Monitoring & Observability

```bash
# Monitor cluster health
python scripts/python/monitor.py --cluster eks-strimzi-dev report

# Kafka client operations
python scripts/python/kafka_client.py --topic my-topic send --message '{"data": "test"}'
python scripts/python/kafka_client.py --topic my-topic consume --group test-group
```

## 📊 Deployment Environments

### Development
- 2 t3.large worker nodes
- 1 Kafka broker replica
- 1 ZooKeeper replica
- Minimal monitoring
- ~$72/month

### Production
- 6 worker nodes (3x t3.xlarge + 3x m5.2xlarge)
- 3 Kafka broker replicas (high availability)
- 3 ZooKeeper replicas
- Full monitoring stack
- ~$1,800/month

## 🏗️ Example Applications

### Java Kafka Consumer (Spring Boot)
```bash
cd applications/java-kafka-consumer
mvn clean package
docker build -t java-kafka-consumer:latest .
kubectl apply -f kubernetes.yaml
```

### .NET Kafka Producer (ASP.NET Core)
```bash
cd applications/dotnet-kafka-producer
dotnet publish -c Release
docker build -t dotnet-kafka-producer:latest .
# Send message: curl -X POST http://localhost:5000/api/produce?topic=my-topic
```

### Python Kafka Monitor
```bash
cd applications/python-kafka-monitor
pip install -r requirements.txt
python monitor.py --cluster eks-strimzi-dev report
```

## 📈 Monitoring & Metrics

- **Prometheus**: Metrics collection and querying
- **Grafana**: Visualization and dashboards
- **Kafka JMX**: Broker and topic metrics
- **Application Metrics**: Spring Boot Actuator, .NET diagnostics
- **System Metrics**: Node CPU, memory, disk usage

Access Grafana:
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Default: admin / [check terraform output]
```

## 🔒 Security Features

- **Network Isolation**: All resources in private subnets
- **IAM Roles**: IRSA for pod-to-AWS service authentication
- **Encryption**: EBS volumes encrypted, TLS for Kafka
- **Audit Logging**: EKS control plane logs to CloudWatch
- **Network Policies**: Kubernetes network policies for pod isolation
- **RBAC**: Role-based access control for API access

## 💰 Cost Optimization

- Dev environment: ~$72/month
- Prod environment: ~$1,800/month
- Spot instances available for non-critical workloads
- Auto-scaling based on metrics
- Reserved instances for predictable workloads

## 📚 Documentation

- [Deployment Guide](docs/DEPLOYMENT.md) - Step-by-step deployment instructions
- [Architecture Overview](docs/README.md) - Detailed architecture and usage
- [Configuration Reference](config/README.md) - Configuration options

## 🔧 Troubleshooting

### Check Kafka Cluster Status
```bash
kubectl describe kafka kafka-cluster -n kafka
kubectl logs -f statefulset/kafka-cluster-kafka -n kafka -c kafka
```

### Check Application Logs
```bash
kubectl logs -f deployment/java-kafka-consumer -n kafka
kubectl logs -f deployment/dotnet-kafka-producer -n kafka
```

### Common Issues
```bash
# Pod not starting
kubectl describe pod <pod-name> -n kafka

# Network connectivity
kubectl run -it kafka-client --image=quay.io/strimzi/kafka:latest -- \
  kafka-broker-api-versions.sh --bootstrap-server kafka-cluster-kafka-bootstrap:9092

# View events
kubectl get events -n kafka --sort-by='.lastTimestamp'
```

## 📝 Windows/macOS/Linux Support

### Shell Scripts (Linux/macOS)
- `scripts/shell/deploy.sh` - Infrastructure deployment
- `scripts/shell/k8s-manage.sh` - Kubernetes operations
- `scripts/shell/aws-helper.sh` - AWS CLI helpers

### Batch Scripts (Windows)
- `scripts/batch/deploy.bat` - Infrastructure deployment
- `scripts/batch/k8s-manage.bat` - Kubernetes operations

### Python Scripts (Cross-platform)
- `scripts/python/monitor.py` - Cluster monitoring
- `scripts/python/kafka_client.py` - Kafka client operations

## 🚀 Next Steps

1. **Deploy Infrastructure**: Follow the [Deployment Guide](docs/DEPLOYMENT.md)
2. **Configure Applications**: Customize application settings
3. **Setup Monitoring**: Configure Prometheus and Grafana
4. **Enable CI/CD**: Configure GitHub Actions or CodePipeline
5. **Implement Security**: Configure SSL/TLS, RBAC, and network policies

## 📞 Support & Contribution

- **Issues**: Report bugs and feature requests via GitHub Issues
- **Discussions**: Use GitHub Discussions for questions
- **Contributing**: See CONTRIBUTING.md for contribution guidelines

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🔗 References

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Strimzi Documentation](https://strimzi.io/docs/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)