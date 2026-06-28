aws ec2 create-key-pair --key-name eks-key --query KeyMaterial --output text > eks-key.pem
chmod 400 eks-key.pem
