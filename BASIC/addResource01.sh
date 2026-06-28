

aws eks update-kubeconfig --name my-micro-cluster

kubectl get nodes

# Trust policy: this badge is worn by EC2 machines (the worker trucks)
cat > eks-node-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the worker node role
aws iam create-role \
  --role-name eksNodeRole \
  --assume-role-policy-document file://eks-node-trust-policy.json