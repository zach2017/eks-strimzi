# Find the security group EKS created for SSH remote access
export SSH_SG=$(aws eks describe-nodegroup \
  --cluster-name my-micro-cluster \
  --nodegroup-name micro-nodes \
  --query 'nodegroup.resources.remoteAccessSecurityGroup' \
  --output text)

  aws ec2 revoke-security-group-ingress \
  --group-id $SSH_SG \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

  aws ec2 revoke-security-group-ingress \
  --group-id $SSH_SG \
  --protocol tcp \
  --port 22 \
  --cidr 68.32.112.68/0

# Open port 22 (SSH) to the whole internet
aws ec2 authorize-security-group-ingress \
  --group-id $SSH_SG \
  --protocol tcp \
  --port 22 \
  --cidr 68.32.112.68/0


  # Get the public IP address of your first worker node
aws ec2 describe-instances \
  --filters "Name=tag:eks:nodegroup-name,Values=micro-nodes" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].PublicIpAddress' \
  --output text

  curl -s https://checkip.amazonaws.com

# SSH in using your key (Amazon Linux's default user is "ec2-user")
#ssh -i eks-ssh-key.pem ec2-user@aaa