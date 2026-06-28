# Deployment Guide

## Prerequisites

Before deploying, ensure you have:

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
3. **Terraform** installed (v1.0+)
4. **kubectl** installed and configured
5. **Docker** (optional, for building images)

## Step-by-Step Deployment

### Step 1: Clone and Setup

```bash
# Clone repository
git clone <repository-url>
cd eks-strimzi

# Set environment variables
export AWS_REGION=us-east-1
export ENVIRONMENT=dev
```

### Step 2: Initialize Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Validate configuration
terraform validate
```

### Step 3: Review Plan

```bash
# Create a plan
terraform plan -var-file="environments/${ENVIRONMENT}/terraform.tfvars" -out="${ENVIRONMENT}.tfplan"

# Review the plan output
cat ${ENVIRONMENT}.tfplan
```

### Step 4: Apply Configuration

```bash
# Apply Terraform changes
terraform apply "${ENVIRONMENT}.tfplan"

# This will:
# - Create VPC and networking
# - Create EKS cluster
# - Create node groups
# - Install Strimzi operator
# - Deploy Kafka cluster
# - Setup monitoring
```

### Step 5: Configure kubectl

```bash
# Get cluster name from Terraform output
CLUSTER_NAME=$(terraform output -raw cluster_name)

# Update kubeconfig
aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### Step 6: Verify Deployment

```bash
# Check Kafka cluster
kubectl get kafka -n kafka

# Wait for Kafka to be ready (10-15 minutes)
kubectl wait --for=condition=Ready kafka/kafka-cluster -n kafka --timeout=900s

# Check pods
kubectl get pods -n kafka

# Check Strimzi operator
kubectl logs -f deployment/strimzi-cluster-operator -n kafka
```

### Step 7: Deploy Applications

```bash
# Build and push images to ECR (optional)
# or use pre-built images

# Deploy Java consumer
kubectl apply -f applications/java-kafka-consumer/kubernetes.yaml

# Deploy .NET producer
kubectl apply -f applications/dotnet-kafka-producer/kubernetes.yaml

# Deploy Python monitor
kubectl apply -f applications/python-kafka-monitor/kubernetes.yaml

# Verify deployments
kubectl get deployments -n kafka
kubectl get pods -n kafka
```

## Verifying the Deployment

### Check Cluster Status

```bash
# Get cluster info
./scripts/shell/aws-helper.sh cluster-info ${CLUSTER_NAME}

# Get nodes
kubectl get nodes -o wide

# Get pods
kubectl get pods -n kafka
```

### Test Kafka

```bash
# Create a test topic
./scripts/shell/k8s-manage.sh topic-create test-topic 3 1 kafka

# List topics
./scripts/shell/k8s-manage.sh topics kafka

# Port forward to Kafka
./scripts/shell/k8s-manage.sh portforward kafka 9092

# In another terminal, test with Kafka client
kafka-console-producer.sh --bootstrap-server localhost:9092 --topic test-topic
```

### Test Applications

```bash
# Check Java consumer
kubectl logs -f deployment/java-kafka-consumer -n kafka

# Check .NET producer
kubectl port-forward svc/dotnet-kafka-producer 5000:5000
curl http://localhost:5000/api/health

# Check Python monitor
kubectl logs -f deployment/python-kafka-monitor -n kafka
```

## Monitoring

### Access Grafana

```bash
# Port forward to Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Open browser
# http://localhost:3000

# Login with credentials from Terraform output
```

### Access Prometheus

```bash
# Port forward to Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Open browser
# http://localhost:9090
```

## Common Deployment Issues

### Issue: EKS cluster creation times out

**Solution:**
```bash
# Check cluster status
aws eks describe-cluster --name ${CLUSTER_NAME} --query 'cluster.status'

# Check CloudFormation stack
aws cloudformation describe-stacks --stack-name ${CLUSTER_NAME}
```

### Issue: Kafka pods not starting

**Solution:**
```bash
# Check Strimzi operator logs
kubectl logs -n kafka deployment/strimzi-cluster-operator

# Check Kafka cluster status
kubectl describe kafka kafka-cluster -n kafka

# Check events
kubectl get events -n kafka --sort-by='.lastTimestamp'
```

### Issue: Node group scaling issues

**Solution:**
```bash
# Check node group status
./scripts/shell/aws-helper.sh nodegroup-info ${CLUSTER_NAME} general

# Check EC2 instances
./scripts/shell/aws-helper.sh instances ${CLUSTER_NAME}

# Check autoscaling groups
aws autoscaling describe-auto-scaling-groups
```

## Cost Estimation

### Dev Environment
- EKS: ~$0.10/hour
- 2x t3.large (on-demand): ~$0.27/hour
- Storage (30GB EBS): ~$3/month
- **Total: ~$72/month**

### Prod Environment
- EKS: ~$0.10/hour
- 3x t3.xlarge + 3x m5.2xlarge: ~$2.50/hour
- Storage (500GB EBS): ~$50/month
- Monitoring: ~$50/month
- **Total: ~$1,800/month**

## Next Steps

1. **Configure CI/CD**: Set up GitHub Actions or CodePipeline
2. **Enable SSL/TLS**: Configure certificate management
3. **Setup backups**: Configure automated backups
4. **Configure RBAC**: Implement role-based access control
5. **Setup logging**: Configure centralized logging with ELK or similar

## Cleanup

To avoid unnecessary costs, destroy resources when not needed:

```bash
# Destroy Terraform resources
./scripts/shell/deploy.sh ${ENVIRONMENT} destroy

# Verify deletion
aws eks list-clusters
aws ec2 describe-vpcs
```

## Getting Help

1. Check logs:
   ```bash
   kubectl logs -n kafka <pod-name>
   ```

2. Check events:
   ```bash
   kubectl get events -n kafka
   ```

3. Check Terraform state:
   ```bash
   terraform state list
   terraform state show <resource>
   ```

4. Check AWS CloudFormation:
   ```bash
   aws cloudformation describe-stacks --stack-name ${CLUSTER_NAME}
   ```
