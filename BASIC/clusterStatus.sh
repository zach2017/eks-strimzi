
aws eks describe-cluster --name my-micro-cluster \
  --query 'cluster.status' --output text