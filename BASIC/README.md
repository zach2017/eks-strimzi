**Create EKS cluster (2x t3.micro nodes, public subnets + SSH):**

```bash
# 1. Key pair
aws ec2 create-key-pair --key-name eks-key --query KeyMaterial --output text > eks-key.pem
chmod 400 eks-key.pem

# 2. Create cluster (eksctl - simplest)
eksctl create cluster \
  --name micro-eks \
  --region us-east-1 \
  --nodegroup-name micro-ng \
  --node-type t3.micro \
  --nodes 2 \
  --node-volume-size 20 \
  --ssh-access \
  --ssh-public-key eks-key \
  --managed
```

**SSH to nodes:**
```bash
ssh -i eks-key.pem ec2-user@<node-public-ip>
```

(eksctl auto-creates public subnets + allows SSH from 0.0.0.0/0 on port 22.)

aws eks update-kubeconfig --region us-east-1 --name micro-eks

kubectl get nodes
kubectl describe node <node-name>