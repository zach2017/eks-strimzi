#!/bin/bash

# ============================================================================
# AWS CLI Helper Script
# ============================================================================

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

# Get cluster info
get_cluster_info() {
    local cluster_name="${1:-}"
    local region="${2:-us-east-1}"
    
    [[ -z "$cluster_name" ]] && error "Cluster name required"
    
    log "Getting cluster info for $cluster_name in $region..."
    aws eks describe-cluster --name "$cluster_name" --region "$region" --query 'cluster.[name,status,version,endpoint,logging.clusterLogging]' --output table
}

# Scale node group
scale_node_group() {
    local cluster_name="${1:-}"
    local node_group_name="${2:-}"
    local desired_size="${3:-}"
    local region="${4:-us-east-1}"
    
    [[ -z "$cluster_name" ]] && error "Cluster name required"
    [[ -z "$node_group_name" ]] && error "Node group name required"
    [[ -z "$desired_size" ]] && error "Desired size required"
    
    log "Scaling node group $node_group_name to $desired_size nodes..."
    aws eks update-nodegroup-config \
        --cluster-name "$cluster_name" \
        --nodegroup-name "$node_group_name" \
        --scaling-config desiredSize="$desired_size" \
        --region "$region"
    
    log "Node group scaled successfully"
}

# List node groups
list_node_groups() {
    local cluster_name="${1:-}"
    local region="${2:-us-east-1}"
    
    [[ -z "$cluster_name" ]] && error "Cluster name required"
    
    log "Node groups in cluster $cluster_name:"
    aws eks list-nodegroups --cluster-name "$cluster_name" --region "$region" --query 'nodegroups[]' --output table
}

# Get node group info
get_node_group_info() {
    local cluster_name="${1:-}"
    local node_group_name="${2:-}"
    local region="${3:-us-east-1}"
    
    [[ -z "$cluster_name" ]] && error "Cluster name required"
    [[ -z "$node_group_name" ]] && error "Node group name required"
    
    log "Node group info for $node_group_name:"
    aws eks describe-nodegroup \
        --cluster-name "$cluster_name" \
        --nodegroup-name "$node_group_name" \
        --region "$region" \
        --query 'nodegroup.[nodegroupName,status,scalingConfig,instances]' \
        --output table
}

# List EC2 instances
list_instances() {
    local cluster_name="${1:-}"
    local region="${2:-us-east-1}"
    
    [[ -z "$cluster_name" ]] && error "Cluster name required"
    
    log "EC2 instances with tag eks:cluster-name=$cluster_name:"
    aws ec2 describe-instances \
        --region "$region" \
        --filters "Name=tag:eks:cluster-name,Values=$cluster_name" "Name=instance-state-name,Values=running" \
        --query 'Reservations[].Instances[].[InstanceId,InstanceType,PrivateIpAddress,State.Name,Tags[?Key==`Name`].Value|[0]]' \
        --output table
}

# Get logs
get_logs() {
    local log_group="${1:-}"
    local region="${2:-us-east-1}"
    
    [[ -z "$log_group" ]] && error "Log group name required"
    
    log "Listing log streams in $log_group..."
    aws logs describe-log-streams --log-group-name "$log_group" --region "$region" --query 'logStreams[].[logStreamName,lastEventTimestamp]' --output table
}

# Tail logs
tail_logs() {
    local log_group="${1:-}"
    local log_stream="${2:-}"
    local region="${3:-us-east-1}"
    
    [[ -z "$log_group" ]] && error "Log group name required"
    [[ -z "$log_stream" ]] && error "Log stream name required"
    
    log "Tailing logs from $log_group/$log_stream..."
    aws logs tail "$log_group" --log-stream-names "$log_stream" --region "$region" --follow
}

usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    cluster-info CLUSTER [REGION]           Get cluster info
    list-nodegroups CLUSTER [REGION]        List node groups
    nodegroup-info CLUSTER NG [REGION]      Get node group info
    scale CLUSTER NG SIZE [REGION]          Scale node group
    instances CLUSTER [REGION]              List EC2 instances
    logs LOG_GROUP [REGION]                 List log streams
    tail-logs LOG_GROUP STREAM [REGION]     Tail logs

Default region: us-east-1

Examples:
    $0 cluster-info eks-strimzi-dev
    $0 scale eks-strimzi-prod general 5 us-east-1
    $0 tail-logs /aws/eks/eks-strimzi-dev/cluster api-server
EOF
    exit 0
}

[[ $# -eq 0 ]] && usage

case "${1:-}" in
    cluster-info)
        get_cluster_info "${2:-}" "${3:-us-east-1}"
        ;;
    list-nodegroups)
        list_node_groups "${2:-}" "${3:-us-east-1}"
        ;;
    nodegroup-info)
        get_node_group_info "${2:-}" "${3:-}" "${4:-us-east-1}"
        ;;
    scale)
        scale_node_group "${2:-}" "${3:-}" "${4:-}" "${5:-us-east-1}"
        ;;
    instances)
        list_instances "${2:-}" "${3:-us-east-1}"
        ;;
    logs)
        get_logs "${2:-}" "${3:-us-east-1}"
        ;;
    tail-logs)
        tail_logs "${2:-}" "${3:-}" "${4:-us-east-1}"
        ;;
    *)
        error "Unknown command: $1"
        ;;
esac
