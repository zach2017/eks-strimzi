# Project Configuration

## Environment Variables

Create a `.env.local` file in the root directory:

```bash
# AWS Configuration
AWS_REGION=us-east-1
AWS_PROFILE=default

# Kubernetes
KUBECONFIG=${HOME}/.kube/config
KUBERNETES_NAMESPACE=kafka

# Kafka Configuration
KAFKA_BOOTSTRAP_SERVERS=kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092
KAFKA_SECURITY_PROTOCOL=PLAINTEXT

# Monitoring
PROMETHEUS_URL=http://localhost:9090
GRAFANA_URL=http://localhost:3000
GRAFANA_ADMIN_PASSWORD=admin123

# Application Configuration
LOG_LEVEL=INFO
ENVIRONMENT=dev
```

## Terraform State Management

### Local State (Development)

Default configuration uses local state files.

### Remote State (Production)

Create S3 bucket for remote state:

```bash
# Create bucket
aws s3 mb s3://eks-strimzi-terraform-state --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket eks-strimzi-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket eks-strimzi-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

Configure remote state in `terraform/main.tf`:

```hcl
backend "s3" {
  bucket         = "eks-strimzi-terraform-state"
  key            = "eks-strimzi/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-locks"
}
```

## AWS Configuration

### IAM Policy

Required permissions for deployment:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:*",
        "ec2:*",
        "iam:*",
        "logs:*",
        "autoscaling:*",
        "cloudformation:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### AWS CLI Configuration

```bash
# Configure AWS CLI
aws configure

# Verify configuration
aws sts get-caller-identity

# Set default region
export AWS_DEFAULT_REGION=us-east-1
```

## Kubernetes Configuration

### kubeconfig Setup

```bash
# Generate kubeconfig from Terraform outputs
aws eks update-kubeconfig \
  --region us-east-1 \
  --name eks-strimzi-dev

# Verify connection
kubectl cluster-info

# View all contexts
kubectl config get-contexts
```

### Namespace Configuration

Create custom namespace:

```bash
# Create namespace with labels
kubectl create namespace kafka \
  --dry-run=client -o yaml | \
  kubectl apply -f -

# Add labels
kubectl label namespace kafka \
  workload=kafka \
  monitoring=enabled
```

## Application Secrets

### Create Secrets

```bash
# Kafka credentials secret
kubectl create secret generic kafka-credentials \
  --from-literal=username=kafka-user \
  --from-literal=password=secure-password \
  -n kafka

# TLS certificates
kubectl create secret tls kafka-tls \
  --cert=path/to/cert.pem \
  --key=path/to/key.pem \
  -n kafka
```

### Reference in Pod

```yaml
env:
- name: KAFKA_USERNAME
  valueFrom:
    secretKeyRef:
      name: kafka-credentials
      key: username
```

## Docker Registry Configuration

### AWS ECR

```bash
# Create ECR repository
aws ecr create-repository \
  --repository-name eks-strimzi/java-kafka-consumer \
  --region us-east-1

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build and push image
docker build -t eks-strimzi/java-kafka-consumer:latest .
docker tag eks-strimzi/java-kafka-consumer:latest \
  <account-id>.dkr.ecr.us-east-1.amazonaws.com/eks-strimzi/java-kafka-consumer:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/eks-strimzi/java-kafka-consumer:latest
```

## Monitoring Configuration

### Prometheus Configuration

Add custom service monitor:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: custom-app
  namespace: kafka
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
  - port: metrics
    interval: 30s
```

### Grafana Datasources

```bash
# Get Prometheus endpoint
PROM_ENDPOINT=$(kubectl get svc -n monitoring kube-prometheus-stack-prometheus -o jsonpath='{.spec.clusterIP}')

# Configure in Grafana UI or via API
curl -X POST http://localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://'"$PROM_ENDPOINT"':9090",
    "access": "proxy"
  }'
```

## Logging Configuration

### CloudWatch Logs

EKS cluster logs are sent to CloudWatch. View logs:

```bash
# Get log groups
aws logs describe-log-groups --query 'logGroups[*].logGroupName'

# Tail logs
aws logs tail /aws/eks/eks-strimzi-dev/cluster --follow
```

### Centralized Logging

Optional: Configure with ELK stack or similar

```bash
# Deploy Elasticsearch
helm install elasticsearch elastic/elasticsearch -n logging

# Deploy Kibana
helm install kibana elastic/kibana -n logging

# Configure log forwarding
kubectl apply -f kubernetes/logging/filebeat.yaml
```

## Backup Configuration

### Automated Backups

Configure backup policies:

```bash
# Create backup plan
aws backup create-backup-plan \
  --backup-plan file://backup-plan.json

# Create backup vault
aws backup create-backup-vault \
  --backup-vault-name eks-strimzi-backups

# Create backup selection
aws backup create-backup-selection \
  --backup-plan-name eks-strimzi-plan \
  --backup-selection file://backup-selection.json
```

### Manual Backup

```bash
# Backup Kubernetes resources
kubectl get all -n kafka -o yaml > kafka-backup.yaml

# Backup Terraform state
cp terraform/terraform.tfstate terraform/terraform.tfstate.backup
```

## Security Configuration

### Network Policies

```bash
# Apply network policies
kubectl apply -f kubernetes/network-policies/
```

### Pod Security Policies

```bash
# Apply pod security standards
kubectl apply -f kubernetes/pod-security/
```

### RBAC Configuration

```bash
# Create service account
kubectl create serviceaccount kafka-app -n kafka

# Bind cluster role
kubectl create clusterrolebinding kafka-app-binding \
  --clusterrole=view \
  --serviceaccount=kafka:kafka-app
```
