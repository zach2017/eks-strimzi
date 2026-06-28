# Quick Reference Guide

## Getting Started (5 minutes)

```bash
# 1. Setup environment
make setup

# 2. Deploy infrastructure
make init
make plan ENVIRONMENT=dev
make apply ENVIRONMENT=dev

# 3. Verify deployment
make k8s-status
make k8s-pods
```

## Common Commands

### Terraform

```bash
# Initialize
terraform -chdir=terraform init

# Plan changes
terraform -chdir=terraform plan -var-file="environments/dev/terraform.tfvars"

# Apply changes
terraform -chdir=terraform apply -var-file="environments/dev/terraform.tfvars"

# Destroy resources
terraform -chdir=terraform destroy -var-file="environments/dev/terraform.tfvars"

# Show outputs
terraform -chdir=terraform output
```

### Kubernetes

```bash
# Get cluster info
kubectl cluster-info
kubectl get nodes
kubectl top nodes

# Get pods
kubectl get pods -n kafka
kubectl get pods -n kafka --watch

# Get services
kubectl get svc -n kafka
kubectl get svc -n monitoring

# Describe resources
kubectl describe pod <pod-name> -n kafka
kubectl describe kafka kafka-cluster -n kafka

# Logs
kubectl logs <pod-name> -n kafka
kubectl logs -f <pod-name> -n kafka
kubectl logs --tail=50 <pod-name> -n kafka

# Execute in pod
kubectl exec -it <pod-name> -n kafka -- /bin/bash
```

### Kafka Topics

```bash
# List topics
./scripts/shell/k8s-manage.sh topics kafka

# Create topic
./scripts/shell/k8s-manage.sh topic-create my-topic 3 2 kafka

# Delete topic
./scripts/shell/k8s-manage.sh topic-delete my-topic kafka
```

### AWS

```bash
# Get cluster info
./scripts/shell/aws-helper.sh cluster-info eks-strimzi-dev

# List node groups
./scripts/shell/aws-helper.sh list-nodegroups eks-strimzi-dev

# Scale node group
./scripts/shell/aws-helper.sh scale eks-strimzi-dev general 5

# Get instances
./scripts/shell/aws-helper.sh instances eks-strimzi-dev

# View logs
./scripts/shell/aws-helper.sh tail-logs /aws/eks/eks-strimzi-dev/cluster api-server
```

### Monitoring

```bash
# View Grafana (port 3000)
make grafana

# View Prometheus (port 9090)
make prometheus

# Monitor cluster
python scripts/python/monitor.py --cluster eks-strimzi-dev report
```

## Troubleshooting

### Cluster Issues

```bash
# Check cluster status
aws eks describe-cluster --name eks-strimzi-dev --query 'cluster.status'

# Check CloudFormation
aws cloudformation describe-stacks --stack-name eks-strimzi-dev

# Check events
kubectl get events -n kafka --sort-by='.lastTimestamp'
```

### Pod Issues

```bash
# Pod stuck in Pending
kubectl describe pod <pod-name> -n kafka

# Pod CrashLoopBackOff
kubectl logs <pod-name> -n kafka --previous

# Check resource limits
kubectl describe resourcequota -n kafka
kubectl describe limits -n kafka
```

### Kafka Issues

```bash
# Check Kafka cluster
kubectl get kafka -n kafka
kubectl describe kafka kafka-cluster -n kafka

# Check Kafka broker logs
kubectl logs -f statefulset/kafka-cluster-kafka -n kafka

# Check broker JMX metrics
kubectl port-forward kafka-cluster-kafka-0 5555:5555 -n kafka
# Connect to localhost:5555
```

## Port Forwarding

```bash
# Kafka broker
kubectl port-forward kafka-cluster-kafka-0 9092:9092 -n kafka

# Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Application
kubectl port-forward svc/dotnet-kafka-producer 5000:5000 -n kafka
```

## Building and Pushing Images

```bash
# Build Java consumer
docker build -t java-kafka-consumer:latest ./applications/java-kafka-consumer
docker tag java-kafka-consumer:latest <registry>/java-kafka-consumer:latest
docker push <registry>/java-kafka-consumer:latest

# Build .NET producer
docker build -t dotnet-kafka-producer:latest ./applications/dotnet-kafka-producer
docker tag dotnet-kafka-producer:latest <registry>/dotnet-kafka-producer:latest
docker push <registry>/dotnet-kafka-producer:latest

# Build Python monitor
docker build -t python-kafka-monitor:latest ./applications/python-kafka-monitor
docker tag python-kafka-monitor:latest <registry>/python-kafka-monitor:latest
docker push <registry>/python-kafka-monitor:latest
```

## Deployment Checklist

- [ ] AWS credentials configured
- [ ] Terraform initialized
- [ ] Environment variables set in .env.local
- [ ] Infrastructure deployed
- [ ] kubectl configured
- [ ] Kafka cluster running
- [ ] Applications deployed
- [ ] Monitoring accessible
- [ ] Test topic created
- [ ] Applications sending/receiving messages

## Environment Variables

```bash
export AWS_REGION=us-east-1
export AWS_PROFILE=default
export KUBECONFIG=${HOME}/.kube/config
export KAFKA_BOOTSTRAP_SERVERS=kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092
export KAFKA_NAMESPACE=kafka
```

## File Locations

- Infrastructure Code: `terraform/`
- Kubernetes Manifests: `kubernetes/`
- Applications: `applications/`
- Scripts: `scripts/`
- Documentation: `docs/`
- Configuration: `config/`

## Useful Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Strimzi Documentation](https://strimzi.io/docs/)
- [Kafka Documentation](https://kafka.apache.org/documentation/)
- [Terraform Documentation](https://www.terraform.io/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## Emergency Procedures

### Destroy Everything
```bash
# Destroy Terraform resources
terraform -chdir=terraform destroy -var-file="environments/dev/terraform.tfvars" -auto-approve

# Remove kubeconfig entry
kubectl config delete-context <context-name>
```

### Restart Kafka Cluster
```bash
# Delete Kafka pods (will auto-restart)
kubectl delete pod -l app=kafka -n kafka

# Wait for cluster to stabilize
kubectl wait --for=condition=Ready kafka/kafka-cluster -n kafka --timeout=600s
```

### Reset Kubeconfig
```bash
# Regenerate kubeconfig
rm ${HOME}/.kube/config
aws eks update-kubeconfig --region us-east-1 --name eks-strimzi-dev
```
