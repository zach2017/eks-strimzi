# Detach the three managed policies + the autoscaler inline policy
aws iam detach-role-policy --role-name eksNodeRole --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
aws iam detach-role-policy --role-name eksNodeRole --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
aws iam detach-role-policy --role-name eksNodeRole --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
aws iam detach-role-policy --role-name eksNodeRole --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore 2>/dev/null

# Remove the inline autoscaler policy (if you added it)
aws iam delete-role-policy --role-name eksNodeRole --policy-name ClusterAutoscalerPolicy 2>/dev/null

# Now the node role can be deleted
aws iam delete-role --role-name eksNodeRole

aws iam detach-role-policy --role-name eksClusterRole --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
aws iam delete-role --role-name eksClusterRole

# Delete the SSH key pair
aws ec2 delete-key-pair --key-name eks-ssh-key

# Delete the local private key file
rm -f eks-ssh-key.pem

# If you allocated an Elastic IP or NAT gateway, release them — these DO bill:
# aws ec2 delete-nat-gateway --nat-gateway-id $NAT_ID
# aws ec2 release-address --allocation-id $EIP_ALLOC