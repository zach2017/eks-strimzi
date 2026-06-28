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