# Save the node role ARN to a variable
# Get the subnet IDs that the cluster was actually created with
export SUBNET_IDS=$(aws eks describe-cluster \
  --name my-micro-cluster \
  --query 'cluster.resourcesVpcConfig.subnetIds' \
  --output text | tr -s '[:space:]' ',' | sed 's/,$//')

echo "SUBNETS: $SUBNET_IDS"

export NODE_ROLE_ARN=$(aws iam get-role \
  --role-name eksNodeRole \
  --query 'Role.Arn' --output text)

# Create the managed node group: 2x t3.micro, SSH key attached
aws eks create-nodegroup \
  --cluster-name my-micro-cluster \
  --nodegroup-name micro-nodes \
  --node-role $NODE_ROLE_ARN \
  --subnets $(echo $SUBNET_IDS | tr ',' ' ') \
  --instance-types t3.micro \
  --scaling-config minSize=2,maxSize=2,desiredSize=2 \
  --remote-access ec2SshKey=eks-ssh-key