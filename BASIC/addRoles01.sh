# Policy 1: lets nodes register with EKS and pull cluster info
aws iam attach-role-policy --role-name eksNodeRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy

# Policy 2: lets nodes set up pod networking (the VPC CNI)
aws iam attach-role-policy --role-name eksNodeRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy

# Policy 3: lets nodes download container images from ECR
aws iam attach-role-policy --role-name eksNodeRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly