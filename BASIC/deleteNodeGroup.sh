
aws eks delete-nodegroup \
  --cluster-name my-micro-cluster \
  --nodegroup-name micro-nodes

  # Wait until this command errors with "ResourceNotFoundException" = fully deleted
aws eks describe-nodegroup \
  --cluster-name my-micro-cluster \
  --nodegroup-name micro-nodes \
  --query 'nodegroup.status' --output text

# Or block until done automatically:
aws eks wait nodegroup-deleted \
  --cluster-name my-micro-cluster \
  --nodegroup-name micro-nodes