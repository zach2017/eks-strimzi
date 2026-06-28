
aws eks delete-cluster --name my-micro-cluster

# Optional: block until fully gone
aws eks wait cluster-deleted --name my-micro-cluster