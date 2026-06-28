#!/bin/bash

# ============================================================================
# Project Setup Script
# Installs dependencies and configures the project
# ============================================================================

set -euo pipefail

echo "Setting up AWS EKS-Strimzi project..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Checking prerequisites...${NC}"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Install from https://aws.amazon.com/cli/"
    exit 1
fi
echo "✅ AWS CLI: $(aws --version)"

# Check Terraform
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not found. Install from https://www.terraform.io/downloads"
    exit 1
fi
echo "✅ Terraform: $(terraform --version | head -1)"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Install from https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi
echo "✅ kubectl: $(kubectl version --client --short 2>/dev/null || echo 'installed')"

# Check Docker
if command -v docker &> /dev/null; then
    echo "✅ Docker: $(docker --version)"
else
    echo "⚠️  Docker not found (optional for building images)"
fi

# Check Python
if command -v python3 &> /dev/null; then
    echo "✅ Python: $(python3 --version)"
else
    echo "⚠️  Python not found (optional for scripts)"
fi

echo ""
echo -e "${GREEN}Setting up project...${NC}"

# Make scripts executable
chmod +x scripts/shell/*.sh 2>/dev/null || true

# Create .env.local if not exists
if [ ! -f .env.local ]; then
    echo -e "${YELLOW}Creating .env.local template...${NC}"
    cat > .env.local << EOF
# AWS Configuration
export AWS_REGION=us-east-1
export AWS_PROFILE=default

# Kubernetes
export KUBERNETES_NAMESPACE=kafka

# Kafka Configuration
export KAFKA_BOOTSTRAP_SERVERS=kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092
EOF
    echo "✅ Created .env.local - customize with your values"
fi

# Initialize Terraform
echo -e "${GREEN}Initializing Terraform...${NC}"
cd terraform
terraform init -upgrade
cd ..

# Install Python dependencies (if Python available)
if command -v python3 &> /dev/null; then
    echo -e "${GREEN}Installing Python dependencies...${NC}"
    python3 -m pip install --upgrade pip > /dev/null 2>&1 || true
    python3 -m pip install -r scripts/python/requirements.txt > /dev/null 2>&1 || true
    echo "✅ Python dependencies installed"
fi

echo ""
echo -e "${GREEN}✅ Project setup completed!${NC}"
echo ""
echo "Next steps:"
echo "  1. Configure AWS credentials: aws configure"
echo "  2. Review terraform/environments/dev/terraform.tfvars"
echo "  3. Deploy infrastructure: ./scripts/shell/deploy.sh dev apply"
echo "  4. View documentation: cat docs/README.md"
echo ""
