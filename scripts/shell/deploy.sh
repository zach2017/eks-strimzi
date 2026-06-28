#!/bin/bash

# ============================================================================
# EKS-Strimzi Deployment Script
# Manages infrastructure deployment using Terraform
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
ENVIRONMENT="${1:-dev}"
ACTION="${2:-plan}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

usage() {
    cat << EOF
Usage: $0 [ENVIRONMENT] [ACTION]

ENVIRONMENT: dev, staging, prod (default: dev)
ACTION: init, plan, apply, destroy, refresh (default: plan)

Examples:
    $0 dev plan
    $0 prod apply
    $0 staging destroy
EOF
    exit 1
}

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    error "Invalid environment. Must be dev, staging, or prod"
fi

# Initialize Terraform if not already initialized
init_terraform() {
    log "Initializing Terraform for $ENVIRONMENT environment..."
    cd "$TERRAFORM_DIR"
    terraform init -upgrade
    log "Terraform initialized successfully"
}

# Plan Terraform changes
plan_terraform() {
    log "Planning Terraform changes for $ENVIRONMENT environment..."
    cd "$TERRAFORM_DIR"
    terraform plan -var-file="environments/$ENVIRONMENT/terraform.tfvars" -out="$ENVIRONMENT.tfplan"
    log "Plan saved to $ENVIRONMENT.tfplan"
}

# Apply Terraform changes
apply_terraform() {
    log "Applying Terraform changes for $ENVIRONMENT environment..."
    cd "$TERRAFORM_DIR"
    
    if [[ ! -f "$ENVIRONMENT.tfplan" ]]; then
        warning "Plan file not found. Creating new plan..."
        plan_terraform
    fi
    
    terraform apply "$ENVIRONMENT.tfplan"
    log "Terraform apply completed successfully"
}

# Destroy Terraform resources
destroy_terraform() {
    warning "About to destroy all resources for $ENVIRONMENT environment!"
    read -p "Are you sure? Type 'yes' to confirm: " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        log "Destroy cancelled"
        return 0
    fi
    
    log "Destroying Terraform resources for $ENVIRONMENT environment..."
    cd "$TERRAFORM_DIR"
    terraform destroy -var-file="environments/$ENVIRONMENT/terraform.tfvars" -auto-approve
    log "Terraform destroy completed successfully"
}

# Refresh Terraform state
refresh_terraform() {
    log "Refreshing Terraform state for $ENVIRONMENT environment..."
    cd "$TERRAFORM_DIR"
    terraform refresh -var-file="environments/$ENVIRONMENT/terraform.tfvars"
    log "Terraform state refreshed successfully"
}

# Show outputs
show_outputs() {
    log "Terraform outputs for $ENVIRONMENT environment:"
    cd "$TERRAFORM_DIR"
    terraform output -var-file="environments/$ENVIRONMENT/terraform.tfvars"
}

# Configure kubectl
configure_kubectl() {
    log "Configuring kubectl..."
    
    cd "$TERRAFORM_DIR"
    CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "")
    REGION=$(grep "aws_region" "environments/$ENVIRONMENT/terraform.tfvars" | cut -d'=' -f2 | tr -d ' "')
    
    if [[ -z "$CLUSTER_NAME" ]]; then
        error "Could not get cluster name from Terraform output. Ensure infrastructure is deployed."
    fi
    
    log "Updating kubeconfig for cluster: $CLUSTER_NAME"
    aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"
    log "kubectl configured successfully"
    
    # Test connection
    kubectl cluster-info
}

# Main logic
case "$ACTION" in
    init)
        init_terraform
        ;;
    plan)
        init_terraform
        plan_terraform
        ;;
    apply)
        init_terraform
        plan_terraform
        apply_terraform
        configure_kubectl
        show_outputs
        ;;
    destroy)
        destroy_terraform
        ;;
    refresh)
        refresh_terraform
        ;;
    outputs)
        show_outputs
        ;;
    kubeconfig)
        configure_kubectl
        ;;
    *)
        error "Invalid action: $ACTION"
        ;;
esac

log "Done!"
