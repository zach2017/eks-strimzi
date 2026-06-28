# AWS EKS + Strimzi Kafka Cluster

Complete infrastructure-as-code project for deploying and managing an Apache Kafka cluster on AWS EKS using Strimzi operator with multi-language microservices support.

## Project Structure

```
eks-strimzi/
├── terraform/                    # Infrastructure as Code (Terraform)
│   ├── modules/                 # Reusable modules
│   │   ├── eks-cluster/        # EKS cluster module
│   │   ├── strimzi/            # Strimzi Kafka operator
│   │   └── monitoring/         # Prometheus & Grafana
│   ├── environments/           # Environment configurations
│   │   ├── dev/
│   │   └── prod/
│   └── *.tf                    # Main Terraform files
│
├── kubernetes/                  # Kubernetes manifests
│   ├── namespaces/            # Namespace definitions
│   ├── strimzi-config/        # Kafka configurations
│   ├── monitoring/            # Monitoring dashboards
│   └── applications/          # Application deployments
│
├── applications/               # Microservices
│   ├── java-kafka-consumer/   # Spring Boot Kafka consumer
│   ├── dotnet-kafka-producer/ # .NET Core Kafka producer
│   └── python-kafka-monitor/  # Python monitoring service
│
├── scripts/                    # Automation scripts
│   ├── shell/                 # Bash scripts (Linux/macOS)
│   ├── batch/                 # Batch scripts (Windows)
│   └── python/                # Python utilities
│
├── config/                     # Configuration files
├── docs/                       # Documentation
└── .github/workflows/          # CI/CD pipelines
```

## Prerequisites

### Required Tools
- **AWS CLI** v2.0+
- **Terraform** v1.0+
- **kubectl** v1.24+
- **Docker** (for building images)
- **Python** 3.9+ (for monitoring scripts)
- **Java** 17 JDK (for building Java services)
- **.NET** 8.0 SDK (for building .NET services)

### AWS Setup
```bash
# Configure AWS credentials
aws configure

# Verify AWS credentials
aws sts get-caller-identity
```

## Quick Start

### 1. Deploy Infrastructure

```bash
# Initialize and deploy to dev environment
cd terraform
./deploy.sh dev apply

# Or for production
./deploy.sh prod apply
```

### 2. Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name eks-strimzi-dev

# Verify cluster access
kubectl cluster-info
kubectl get nodes
```

### 3. Deploy Strimzi and Kafka

```bash
# Check Kafka cluster status
./scripts/shell/k8s-manage.sh status kafka

# Wait for Kafka to be ready
./scripts/shell/k8s-manage.sh wait kafka kafka-cluster-entity-operator

# List topics
./scripts/shell/k8s-manage.sh topics kafka
```

### 4. Deploy Example Applications

```bash
# Build and push images (optional)
docker build -t java-kafka-consumer:latest ./applications/java-kafka-consumer
docker build -t dotnet-kafka-producer:latest ./applications/dotnet-kafka-producer
docker build -t python-kafka-monitor:latest ./applications/python-kafka-monitor

# Deploy applications
kubectl apply -f applications/java-kafka-consumer/kubernetes.yaml
kubectl apply -f applications/dotnet-kafka-producer/kubernetes.yaml
kubectl apply -f applications/python-kafka-monitor/kubernetes.yaml

# Check deployment status
kubectl get pods -n kafka
```

## Usage

### Terraform Management

```bash
# Development environment
./scripts/shell/deploy.sh dev plan
./scripts/shell/deploy.sh dev apply
./scripts/shell/deploy.sh dev destroy

# Production environment with higher availability
./scripts/shell/deploy.sh prod apply

# Show outputs
./scripts/shell/deploy.sh prod outputs
```

### Kubernetes Management

```bash
# Check cluster status
./scripts/shell/k8s-manage.sh status kafka

# Manage topics
./scripts/shell/k8s-manage.sh topic-create my-topic 3 3 kafka
./scripts/shell/k8s-manage.sh topic-delete my-topic kafka

# Port forward to Kafka
./scripts/shell/k8s-manage.sh portforward kafka 9092 9092

# Check pod logs
kubectl logs -f deployment/java-kafka-consumer -n kafka
```

### AWS Management

```bash
# Get cluster information
./scripts/shell/aws-helper.sh cluster-info eks-strimzi-dev us-east-1

# List and scale node groups
./scripts/shell/aws-helper.sh list-nodegroups eks-strimzi-dev
./scripts/shell/aws-helper.sh scale eks-strimzi-dev general 5 us-east-1

# View logs
./scripts/shell/aws-helper.sh logs /aws/eks/eks-strimzi-dev/cluster
./scripts/shell/aws-helper.sh tail-logs /aws/eks/eks-strimzi-dev/cluster api-server
```

### Python Monitoring

```bash
# Monitor cluster
python scripts/python/monitor.py --cluster eks-strimzi-dev --region us-east-1 report

# Get cluster status
python scripts/python/monitor.py --cluster eks-strimzi-dev cluster

# Get Kafka topics
python scripts/python/monitor.py --cluster eks-strimzi-dev topics

# Send/consume Kafka messages
python scripts/python/kafka_client.py --topic example-topic send --message '{"key": "test"}'
python scripts/python/kafka_client.py --topic example-topic consume --group test-group --count 10
```

## Configuration

### Environment Variables

```bash
# AWS
export AWS_REGION=us-east-1
export AWS_PROFILE=default

# Kubernetes
export KUBECONFIG=~/.kube/config

# Kafka
export KAFKA_BOOTSTRAP_SERVERS=kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092
export KAFKA_NAMESPACE=kafka
```

### Terraform Variables

Edit environment-specific `terraform.tfvars`:

```hcl
# Dev environment (2 brokers)
kafka_brokers      = 2
zookeeper_replicas = 1
kafka_storage_size = "10Gi"

# Prod environment (3 brokers)
kafka_brokers      = 3
zookeeper_replicas = 3
kafka_storage_size = "100Gi"
```

## Monitoring

### Prometheus & Grafana

Access monitoring dashboards:

```bash
# Port forward Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Default credentials
# Username: admin
# Password: [check terraform outputs]
```

### Metrics

- **Kafka Metrics**: Available on broker pods at port 5556
- **JMX Metrics**: Prometheus exporters on broker pods
- **Application Metrics**: Spring Boot Actuator endpoints

## Applications

### Java Kafka Consumer

Spring Boot application consuming messages from Kafka:

```bash
# Build
cd applications/java-kafka-consumer
mvn clean package

# Run locally
java -jar target/java-kafka-consumer-1.0.0.jar

# Deploy to Kubernetes
kubectl apply -f kubernetes.yaml

# View logs
kubectl logs -f deployment/java-kafka-consumer -n kafka
```

### .NET Kafka Producer

ASP.NET Core application producing messages to Kafka:

```bash
# Build
cd applications/dotnet-kafka-producer
dotnet publish -c Release

# Run locally
dotnet KafkaProducer.dll

# Send message via HTTP
curl -X POST "http://localhost:5000/api/produce?topic=example-topic&key=my-key" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello Kafka"}'
```

### Python Kafka Monitor

Python monitoring application:

```bash
# Install dependencies
pip install -r scripts/python/requirements.txt

# Run monitor
python scripts/python/monitor.py --cluster eks-strimzi-dev report

# Deploy to Kubernetes
kubectl apply -f applications/python-kafka-monitor/kubernetes.yaml
```

## Scaling

### Horizontal Scaling

```bash
# Scale node group
./scripts/shell/aws-helper.sh scale eks-strimzi-prod general 10 us-east-1

# Scale Kafka brokers
# Edit terraform.tfvars and update kafka_brokers variable
terraform apply
```

### Vertical Scaling

```bash
# Update instance types in terraform.tfvars
instance_types = ["t3.2xlarge"]

# Apply changes
terraform apply
```

## Troubleshooting

### Kafka Cluster Issues

```bash
# Check Kafka cluster status
kubectl describe kafka kafka-cluster -n kafka

# Check broker logs
kubectl logs -f statefulset/kafka-cluster-kafka -n kafka

# Check topic status
kubectl get kafkatopics -n kafka
```

### Pod Issues

```bash
# Check pod events
kubectl describe pod <pod-name> -n kafka

# View pod logs
kubectl logs -f <pod-name> -n kafka

# Execute commands in pod
kubectl exec -it <pod-name> -n kafka -- /bin/bash
```

### Network Issues

```bash
# Test connectivity to Kafka
kubectl run -it --rm kafka-client --image=quay.io/strimzi/kafka:latest -- \
  kafka-broker-api-versions.sh --bootstrap-server kafka-cluster-kafka-bootstrap:9092
```

## Cost Optimization

### Development Environment
- 2 t3.large nodes
- 1 Kafka broker replica
- 1 ZooKeeper replica
- No high availability

### Production Environment
- 3 t3.xlarge + 3 m5.2xlarge nodes
- 3 Kafka broker replicas
- 3 ZooKeeper replicas
- Full HA setup with monitoring

## Security Considerations

1. **Network**: All components in private subnets
2. **IAM**: Least privilege access using IRSA
3. **Encryption**: EBS encryption enabled
4. **Audit**: EKS control plane logging enabled
5. **TLS**: Kafka inter-broker communication encrypted

## Maintenance

### Backup

```bash
# Backup Kafka topics
kafka-topics.sh --bootstrap-server kafka-cluster-kafka-bootstrap:9092 --list > topics-backup.txt

# Backup Kubernetes resources
kubectl get all -n kafka -o yaml > kafka-backup.yaml
```

### Updates

```bash
# Update Terraform modules
terraform init -upgrade

# Update Strimzi operator
helm repo update strimzi
terraform apply

# Update applications
kubectl set image deployment/java-kafka-consumer \
  java-kafka-consumer=java-kafka-consumer:new-version -n kafka
```

## Support

For issues or questions:
1. Check logs: `kubectl logs -n kafka -l app=...`
2. Review Terraform outputs: `terraform output`
3. Check AWS resources: `aws eks describe-cluster --name eks-strimzi-dev`

## License

This project is licensed under the MIT License - see LICENSE file for details.

## Contributing

1. Create a feature branch
2. Make your changes
3. Run tests
4. Submit a pull request

## References

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Strimzi Documentation](https://strimzi.io/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
