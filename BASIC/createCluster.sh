#!/usr/bin/env bash

###############################################################################
# Script Name:
#   create-eks-cluster-small-subnets.sh
#
# Purpose:
#   Create a small, dedicated AWS network and start an Amazon EKS cluster.
#
# What this script creates:
#   1. EC2 SSH key pair
#   2. Small dedicated VPC
#   3. Internet Gateway
#   4. Public route table
#   5. Two small public subnets in two Availability Zones
#   6. EKS IAM trust policy file
#   7. EKS IAM cluster role
#   8. AmazonEKSClusterPolicy attachment
#   9. EKS control plane
#
# Important:
#   This creates the EKS control plane only.
#   It does not create worker nodes yet.
#
# Requirements:
#   - AWS CLI installed
#   - AWS CLI configured with credentials
#   - Permissions for EC2, IAM, and EKS
#
# Example:
#   chmod +x create-eks-cluster-small-subnets.sh
#   ./create-eks-cluster-small-subnets.sh
###############################################################################

set -euo pipefail

###############################################################################
# User settings
#
# You can change these names and CIDR ranges if needed.
# CIDR means "the size of the network."
# A /20 VPC is small for AWS labs but still has room for several subnets.
# A /27 subnet has 32 IP addresses, with 27 usable by AWS resources.
###############################################################################

CLUSTER_NAME="my-micro-cluster"
KEY_NAME="eks-ssh-key"
VPC_NAME="${CLUSTER_NAME}-vpc"
VPC_CIDR="10.60.0.0/20"
PUBLIC_SUBNET_1_CIDR="10.60.0.0/27"
PUBLIC_SUBNET_2_CIDR="10.60.0.32/27"
CLUSTER_ROLE_NAME="eksClusterRole"
TRUST_POLICY_FILE="eks-cluster-trust-policy.json"

###############################################################################
# Step 0: Confirm AWS CLI access
#
# This command checks that the AWS CLI can talk to AWS using your configured
# credentials.
###############################################################################

echo "Checking AWS CLI identity..."

aws sts get-caller-identity

###############################################################################
# Step 0.1: Find the active AWS region
#
# EKS and EC2 resources are regional.
# This command reads the region from your AWS CLI profile.
###############################################################################

echo "Checking AWS CLI region..."

AWS_REGION="$(aws configure get region)"

if [ -z "${AWS_REGION}" ]; then
  echo "ERROR: No AWS region is configured."
  echo "Fix it with an example command like:"
  echo "aws configure set region us-east-1"
  exit 1
fi

echo "Using AWS region: ${AWS_REGION}"

###############################################################################
# Step 1: Create an EC2 SSH key pair
#
# This key can be used later if you create EC2 worker nodes that allow SSH.
# If the key already exists in AWS, the script keeps going.
###############################################################################

echo "Checking whether EC2 key pair '${KEY_NAME}' already exists..."

if aws ec2 describe-key-pairs --key-names "${KEY_NAME}" >/dev/null 2>&1; then
  echo "Key pair already exists in AWS: ${KEY_NAME}"
else
  echo "Creating EC2 key pair '${KEY_NAME}' and saving private key to ${KEY_NAME}.pem..."

  aws ec2 create-key-pair \
    --key-name "${KEY_NAME}" \
    --query 'KeyMaterial' \
    --output text > "${KEY_NAME}.pem"

  echo "Setting secure file permissions on ${KEY_NAME}.pem..."

  chmod 400 "${KEY_NAME}.pem"
fi

###############################################################################
# Step 2: Create a small dedicated VPC
#
# A VPC is your private AWS network.
# This script creates a new VPC so EKS does not depend on the default VPC.
###############################################################################

echo "Creating VPC '${VPC_NAME}' with CIDR ${VPC_CIDR}..."

VPC_ID="$(aws ec2 create-vpc \
  --cidr-block "${VPC_CIDR}" \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${VPC_NAME}}]" \
  --query 'Vpc.VpcId' \
  --output text)"

echo "Created VPC: ${VPC_ID}"

###############################################################################
# Step 3: Enable DNS support and DNS hostnames for the VPC
#
# EKS expects normal DNS behavior inside the VPC.
# These commands make AWS DNS names work correctly in this network.
###############################################################################

echo "Enabling DNS support for VPC ${VPC_ID}..."

aws ec2 modify-vpc-attribute \
  --vpc-id "${VPC_ID}" \
  --enable-dns-support '{"Value":true}'

echo "Enabling DNS hostnames for VPC ${VPC_ID}..."

aws ec2 modify-vpc-attribute \
  --vpc-id "${VPC_ID}" \
  --enable-dns-hostnames '{"Value":true}'

###############################################################################
# Step 4: Create and attach an Internet Gateway
#
# An Internet Gateway lets public subnets reach the internet.
# This is useful for a simple EKS lab cluster.
###############################################################################

echo "Creating Internet Gateway for VPC ${VPC_ID}..."

IGW_ID="$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${CLUSTER_NAME}-igw}]" \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)"

echo "Created Internet Gateway: ${IGW_ID}"

echo "Attaching Internet Gateway ${IGW_ID} to VPC ${VPC_ID}..."

aws ec2 attach-internet-gateway \
  --internet-gateway-id "${IGW_ID}" \
  --vpc-id "${VPC_ID}"

###############################################################################
# Step 5: Create a public route table
#
# A route table is like a traffic map.
# This route table sends internet traffic to the Internet Gateway.
###############################################################################

echo "Creating public route table..."

ROUTE_TABLE_ID="$(aws ec2 create-route-table \
  --vpc-id "${VPC_ID}" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${CLUSTER_NAME}-public-rt}]" \
  --query 'RouteTable.RouteTableId' \
  --output text)"

echo "Created route table: ${ROUTE_TABLE_ID}"

echo "Adding default internet route 0.0.0.0/0 through Internet Gateway ${IGW_ID}..."

aws ec2 create-route \
  --route-table-id "${ROUTE_TABLE_ID}" \
  --destination-cidr-block "0.0.0.0/0" \
  --gateway-id "${IGW_ID}"

###############################################################################
# Step 6: Pick two Availability Zones
#
# EKS needs subnets in at least two Availability Zones for a normal cluster.
# This command asks AWS for two available zones in the current region.
###############################################################################

echo "Finding two available Availability Zones in ${AWS_REGION}..."

AZ_1="$(aws ec2 describe-availability-zones \
  --filters "Name=state,Values=available" \
  --query 'AvailabilityZones[0].ZoneName' \
  --output text)"

AZ_2="$(aws ec2 describe-availability-zones \
  --filters "Name=state,Values=available" \
  --query 'AvailabilityZones[1].ZoneName' \
  --output text)"

if [ -z "${AZ_1}" ] || [ "${AZ_1}" = "None" ] || [ -z "${AZ_2}" ] || [ "${AZ_2}" = "None" ]; then
  echo "ERROR: Could not find two available Availability Zones."
  exit 1
fi

echo "Using Availability Zones: ${AZ_1}, ${AZ_2}"

###############################################################################
# Step 7: Create the first small public subnet
#
# This subnet uses CIDR ${PUBLIC_SUBNET_1_CIDR}.
# The EKS tags help Kubernetes load balancers discover the subnet later.
###############################################################################

echo "Creating public subnet 1 with CIDR ${PUBLIC_SUBNET_1_CIDR} in ${AZ_1}..."

PUBLIC_SUBNET_1_ID="$(aws ec2 create-subnet \
  --vpc-id "${VPC_ID}" \
  --cidr-block "${PUBLIC_SUBNET_1_CIDR}" \
  --availability-zone "${AZ_1}" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${CLUSTER_NAME}-public-subnet-1},{Key=kubernetes.io/cluster/${CLUSTER_NAME},Value=shared},{Key=kubernetes.io/role/elb,Value=1}]" \
  --query 'Subnet.SubnetId' \
  --output text)"

echo "Created public subnet 1: ${PUBLIC_SUBNET_1_ID}"

###############################################################################
# Step 8: Create the second small public subnet
#
# This subnet uses CIDR ${PUBLIC_SUBNET_2_CIDR}.
# It is placed in a different Availability Zone from subnet 1.
###############################################################################

echo "Creating public subnet 2 with CIDR ${PUBLIC_SUBNET_2_CIDR} in ${AZ_2}..."

PUBLIC_SUBNET_2_ID="$(aws ec2 create-subnet \
  --vpc-id "${VPC_ID}" \
  --cidr-block "${PUBLIC_SUBNET_2_CIDR}" \
  --availability-zone "${AZ_2}" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${CLUSTER_NAME}-public-subnet-2},{Key=kubernetes.io/cluster/${CLUSTER_NAME},Value=shared},{Key=kubernetes.io/role/elb,Value=1}]" \
  --query 'Subnet.SubnetId' \
  --output text)"

echo "Created public subnet 2: ${PUBLIC_SUBNET_2_ID}"

###############################################################################
# Step 9: Turn on auto-assign public IPv4 addresses for both public subnets
#
# This helps EC2 instances launched in these public subnets receive public IPs.
###############################################################################

echo "Enabling auto-assign public IPv4 address for subnet ${PUBLIC_SUBNET_1_ID}..."

aws ec2 modify-subnet-attribute \
  --subnet-id "${PUBLIC_SUBNET_1_ID}" \
  --map-public-ip-on-launch

echo "Enabling auto-assign public IPv4 address for subnet ${PUBLIC_SUBNET_2_ID}..."

aws ec2 modify-subnet-attribute \
  --subnet-id "${PUBLIC_SUBNET_2_ID}" \
  --map-public-ip-on-launch

###############################################################################
# Step 10: Associate both subnets with the public route table
#
# This makes the subnets public because their route table has an internet route.
###############################################################################

echo "Associating subnet ${PUBLIC_SUBNET_1_ID} with route table ${ROUTE_TABLE_ID}..."

aws ec2 associate-route-table \
  --subnet-id "${PUBLIC_SUBNET_1_ID}" \
  --route-table-id "${ROUTE_TABLE_ID}"

echo "Associating subnet ${PUBLIC_SUBNET_2_ID} with route table ${ROUTE_TABLE_ID}..."

aws ec2 associate-route-table \
  --subnet-id "${PUBLIC_SUBNET_2_ID}" \
  --route-table-id "${ROUTE_TABLE_ID}"

###############################################################################
# Step 11: Build the comma-separated subnet ID list for EKS
#
# This fixes the earlier error:
#   InvalidParameterException: Subnet Id is required
#
# The EKS create-cluster command needs subnet IDs like this:
#   subnet-abc123,subnet-def456
###############################################################################

echo "Building subnet ID list for EKS..."

SUBNET_IDS="${PUBLIC_SUBNET_1_ID},${PUBLIC_SUBNET_2_ID}"

if [ -z "${SUBNET_IDS}" ] || [ "${SUBNET_IDS}" = "," ]; then
  echo "ERROR: Subnet IDs are empty."
  exit 1
fi

echo "EKS subnet IDs: ${SUBNET_IDS}"

###############################################################################
# Step 12: Create the IAM trust policy file for EKS
#
# This file says that the EKS service is allowed to use the IAM role.
###############################################################################

echo "Creating EKS trust policy file: ${TRUST_POLICY_FILE}..."

cat > "${TRUST_POLICY_FILE}" << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

###############################################################################
# Step 13: Create the IAM role for the EKS cluster
#
# This role gives the EKS control plane permission to manage AWS resources.
# If the role already exists, the script uses the existing role.
###############################################################################

echo "Checking whether IAM role '${CLUSTER_ROLE_NAME}' already exists..."

if aws iam get-role --role-name "${CLUSTER_ROLE_NAME}" >/dev/null 2>&1; then
  echo "IAM role already exists: ${CLUSTER_ROLE_NAME}"
else
  echo "Creating IAM role '${CLUSTER_ROLE_NAME}'..."

  aws iam create-role \
    --role-name "${CLUSTER_ROLE_NAME}" \
    --assume-role-policy-document "file://${TRUST_POLICY_FILE}"
fi

###############################################################################
# Step 14: Attach the required EKS cluster policy
#
# AmazonEKSClusterPolicy gives the EKS control plane the permissions it needs.
###############################################################################

echo "Attaching AmazonEKSClusterPolicy to IAM role ${CLUSTER_ROLE_NAME}..."

aws iam attach-role-policy \
  --role-name "${CLUSTER_ROLE_NAME}" \
  --policy-arn "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"

###############################################################################
# Step 15: Get the IAM role ARN
#
# ARN means Amazon Resource Name.
# EKS needs the full role ARN to create the cluster.
###############################################################################

echo "Getting IAM role ARN for ${CLUSTER_ROLE_NAME}..."

CLUSTER_ROLE_ARN="$(aws iam get-role \
  --role-name "${CLUSTER_ROLE_NAME}" \
  --query 'Role.Arn' \
  --output text)"

echo "Cluster role ARN: ${CLUSTER_ROLE_ARN}"

###############################################################################
# Step 16: Create the EKS control plane
#
# This starts the EKS Kubernetes control plane.
# It may take 10 to 20 minutes to become ACTIVE.
###############################################################################

echo "Creating EKS cluster '${CLUSTER_NAME}'..."

aws eks create-cluster \
  --name "${CLUSTER_NAME}" \
  --role-arn "${CLUSTER_ROLE_ARN}" \
  --resources-vpc-config "subnetIds=${SUBNET_IDS},endpointPublicAccess=true,endpointPrivateAccess=true"

###############################################################################
# Step 17: Show helpful next commands
#
# These commands let you check progress and configure kubectl after creation.
###############################################################################

echo "EKS cluster creation has started."
echo ""
echo "Check cluster status with:"
echo "aws eks describe-cluster --name ${CLUSTER_NAME} --query 'cluster.status' --output text"
echo ""
echo "When the cluster is ACTIVE, configure kubectl with:"
echo "aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}"
echo ""
echo "Then test Kubernetes access with:"
echo "kubectl get svc"

# Watch the status until it says "ACTIVE"
aws eks describe-cluster --name my-micro-cluster \
  --query 'cluster.status' --output text

