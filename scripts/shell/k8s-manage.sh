#!/bin/bash

# ============================================================================
# Kubernetes Management Script
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KUBERNETES_DIR="${SCRIPT_DIR}/../kubernetes"

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

# Deploy Kubernetes manifests
deploy_manifests() {
    local namespace="${1:-kafka}"
    local path="${2:-$KUBERNETES_DIR}"
    
    log "Deploying Kubernetes manifests from $path to namespace $namespace..."
    
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f "$path" -n "$namespace"
    
    log "Manifests deployed successfully"
}

# Check pod status
check_pods() {
    local namespace="${1:-kafka}"
    
    log "Checking pod status in namespace $namespace..."
    kubectl get pods -n "$namespace" -o wide
}

# Wait for deployment
wait_deployment() {
    local namespace="${1:-kafka}"
    local deployment="${2:-kafka-cluster-entity-operator}"
    local timeout="${3:-300}"
    
    log "Waiting for deployment $deployment in namespace $namespace (timeout: ${timeout}s)..."
    kubectl wait --for=condition=available --timeout="${timeout}s" \
        deployment/"$deployment" -n "$namespace" 2>/dev/null || warning "Deployment wait timed out"
}

# Get Kafka cluster info
kafka_info() {
    local namespace="${1:-kafka}"
    
    log "Kafka cluster information:"
    kubectl get kafka -n "$namespace" -o yaml
}

# List topics
list_topics() {
    local namespace="${1:-kafka}"
    
    log "Kafka topics:"
    kubectl get kafkatopics -n "$namespace"
}

# Create topic
create_topic() {
    local name="${1:-}"
    local partitions="${2:-3}"
    local replicas="${3:-3}"
    local namespace="${4:-kafka}"
    
    [[ -z "$name" ]] && error "Topic name required"
    
    log "Creating topic: $name (partitions: $partitions, replicas: $replicas)..."
    
    cat << EOF | kubectl apply -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: $name
  namespace: $namespace
  labels:
    strimzi.io/cluster: kafka-cluster
spec:
  partitions: $partitions
  replicationFactor: $replicas
EOF
    
    log "Topic created successfully"
}

# Delete topic
delete_topic() {
    local name="${1:-}"
    local namespace="${2:-kafka}"
    
    [[ -z "$name" ]] && error "Topic name required"
    
    log "Deleting topic: $name..."
    kubectl delete kafkatopic "$name" -n "$namespace"
    log "Topic deleted successfully"
}

# Port forward to Kafka
port_forward() {
    local namespace="${1:-kafka}"
    local local_port="${2:-9092}"
    local remote_port="${3:-9092}"
    
    log "Setting up port forward: localhost:$local_port -> kafka-cluster-kafka-0:$remote_port"
    kubectl port-forward -n "$namespace" "kafka-cluster-kafka-0" "$local_port:$remote_port"
}

# Get cluster status
cluster_status() {
    local namespace="${1:-kafka}"
    
    log "Cluster status:"
    echo ""
    echo "=== Kafka Cluster ==="
    kubectl get kafka -n "$namespace"
    echo ""
    echo "=== Pods ==="
    kubectl get pods -n "$namespace" -l strimzi.io/cluster=kafka-cluster
    echo ""
    echo "=== PVC ==="
    kubectl get pvc -n "$namespace" -l strimzi.io/cluster=kafka-cluster
}

usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    deploy [namespace] [path]       Deploy Kubernetes manifests
    pods [namespace]                Check pod status
    wait [namespace] [deployment]   Wait for deployment to be ready
    info [namespace]                Get Kafka cluster info
    topics [namespace]              List topics
    topic-create NAME [PART] [REP]  Create topic
    topic-delete NAME [namespace]   Delete topic
    portforward [namespace] [PORT]  Port forward to Kafka
    status [namespace]              Show cluster status
    help                            Show this help message

Examples:
    $0 deploy kafka kubernetes/
    $0 pods kafka
    $0 topics kafka
    $0 topic-create my-topic 3 3 kafka
EOF
    exit 0
}

[[ $# -eq 0 ]] && usage

case "${1:-}" in
    deploy)
        deploy_manifests "${2:-kafka}" "${3:-$KUBERNETES_DIR}"
        ;;
    pods)
        check_pods "${2:-kafka}"
        ;;
    wait)
        wait_deployment "${2:-kafka}" "${3:-kafka-cluster-entity-operator}" "${4:-300}"
        ;;
    info)
        kafka_info "${2:-kafka}"
        ;;
    topics)
        list_topics "${2:-kafka}"
        ;;
    topic-create)
        create_topic "${2:-}" "${3:-3}" "${4:-3}" "${5:-kafka}"
        ;;
    topic-delete)
        delete_topic "${2:-}" "${3:-kafka}"
        ;;
    portforward)
        port_forward "${2:-kafka}" "${3:-9092}" "${4:-9092}"
        ;;
    status)
        cluster_status "${2:-kafka}"
        ;;
    help)
        usage
        ;;
    *)
        error "Unknown command: $1"
        ;;
esac
