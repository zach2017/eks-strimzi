#!/usr/bin/env python3

"""
AWS EKS-Strimzi Cluster Monitor
Monitors cluster health, pods, and Kafka metrics
"""

import argparse
import json
import subprocess
import sys
from datetime import datetime
from typing import Dict, List, Any

import boto3
import requests
from tabulate import tabulate


class ClusterMonitor:
    """Monitor EKS cluster and Kafka"""
    
    def __init__(self, cluster_name: str, region: str = "us-east-1"):
        self.cluster_name = cluster_name
        self.region = region
        self.eks_client = boto3.client("eks", region_name=region)
        self.ec2_client = boto3.client("ec2", region_name=region)
    
    def get_cluster_status(self) -> Dict[str, Any]:
        """Get EKS cluster status"""
        try:
            response = self.eks_client.describe_cluster(name=self.cluster_name)
            cluster = response["cluster"]
            return {
                "name": cluster["name"],
                "status": cluster["status"],
                "version": cluster["version"],
                "endpoint": cluster["endpoint"],
                "created_at": str(cluster["createdAt"]),
                "logging": cluster.get("logging", {})
            }
        except Exception as e:
            print(f"Error getting cluster status: {e}", file=sys.stderr)
            return {}
    
    def get_node_groups(self) -> List[Dict[str, Any]]:
        """Get information about node groups"""
        try:
            response = self.eks_client.list_nodegroups(clusterName=self.cluster_name)
            nodegroups = []
            
            for ng_name in response.get("nodegroups", []):
                ng_response = self.eks_client.describe_nodegroup(
                    clusterName=self.cluster_name,
                    nodegroupName=ng_name
                )
                ng = ng_response["nodegroup"]
                nodegroups.append({
                    "name": ng["nodegroupName"],
                    "status": ng["status"],
                    "desired": ng["scalingConfig"]["desiredSize"],
                    "min": ng["scalingConfig"]["minSize"],
                    "max": ng["scalingConfig"]["maxSize"],
                    "instance_types": ", ".join(ng["instanceTypes"]),
                    "instances": len(ng.get("resources", {}).get("autoScalingGroups", []))
                })
            
            return nodegroups
        except Exception as e:
            print(f"Error getting node groups: {e}", file=sys.stderr)
            return []
    
    def get_pods_status(self, namespace: str = "kafka") -> List[Dict[str, Any]]:
        """Get pod status using kubectl"""
        try:
            result = subprocess.run(
                ["kubectl", "get", "pods", "-n", namespace, "-o", "json"],
                capture_output=True,
                text=True,
                check=True
            )
            data = json.loads(result.stdout)
            pods = []
            
            for pod in data.get("items", []):
                pods.append({
                    "name": pod["metadata"]["name"],
                    "namespace": pod["metadata"]["namespace"],
                    "status": pod["status"]["phase"],
                    "ready": pod["status"].get("conditions", [{}])[0].get("status", "Unknown"),
                    "restarts": pod["status"]["containerStatuses"][0].get("restartCount", 0) if pod["status"]["containerStatuses"] else 0
                })
            
            return pods
        except Exception as e:
            print(f"Error getting pods: {e}", file=sys.stderr)
            return []
    
    def get_kafka_topics(self, namespace: str = "kafka") -> List[str]:
        """Get Kafka topics"""
        try:
            result = subprocess.run(
                ["kubectl", "get", "kafkatopics", "-n", namespace, "-o", "json"],
                capture_output=True,
                text=True,
                check=True
            )
            data = json.loads(result.stdout)
            topics = [item["metadata"]["name"] for item in data.get("items", [])]
            return topics
        except Exception as e:
            print(f"Error getting Kafka topics: {e}", file=sys.stderr)
            return []
    
    def print_status_report(self):
        """Print cluster status report"""
        print("\n" + "="*80)
        print(f"EKS Cluster Status Report - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("="*80 + "\n")
        
        # Cluster status
        cluster_status = self.get_cluster_status()
        if cluster_status:
            print("Cluster Information:")
            for key, value in cluster_status.items():
                if key != "logging":
                    print(f"  {key.replace('_', ' ').title()}: {value}")
            print()
        
        # Node groups
        node_groups = self.get_node_groups()
        if node_groups:
            print("Node Groups:")
            print(tabulate(node_groups, headers="keys"))
            print()
        
        # Pods
        pods = self.get_pods_status()
        if pods:
            print("Pod Status:")
            print(tabulate(pods, headers="keys"))
            print()
        
        # Topics
        topics = self.get_kafka_topics()
        if topics:
            print(f"Kafka Topics ({len(topics)}):")
            for topic in topics:
                print(f"  - {topic}")
            print()


def main():
    parser = argparse.ArgumentParser(description="EKS-Strimzi Cluster Monitor")
    parser.add_argument("--cluster", required=True, help="EKS cluster name")
    parser.add_argument("--region", default="us-east-1", help="AWS region")
    parser.add_argument("--namespace", default="kafka", help="Kubernetes namespace")
    parser.add_argument("--format", choices=["table", "json"], default="table", help="Output format")
    
    subparsers = parser.add_subparsers(dest="command", help="Command to run")
    
    subparsers.add_parser("cluster", help="Get cluster status")
    subparsers.add_parser("nodegroups", help="Get node groups")
    subparsers.add_parser("pods", help="Get pod status")
    subparsers.add_parser("topics", help="Get Kafka topics")
    subparsers.add_parser("report", help="Print full status report")
    
    args = parser.parse_args()
    
    monitor = ClusterMonitor(args.cluster, args.region)
    
    if args.command == "cluster":
        status = monitor.get_cluster_status()
        print(json.dumps(status, indent=2) if args.format == "json" else str(status))
    elif args.command == "nodegroups":
        nodegroups = monitor.get_node_groups()
        if args.format == "json":
            print(json.dumps(nodegroups, indent=2))
        else:
            print(tabulate(nodegroups, headers="keys"))
    elif args.command == "pods":
        pods = monitor.get_pods_status(args.namespace)
        if args.format == "json":
            print(json.dumps(pods, indent=2))
        else:
            print(tabulate(pods, headers="keys"))
    elif args.command == "topics":
        topics = monitor.get_kafka_topics(args.namespace)
        print(json.dumps(topics, indent=2) if args.format == "json" else "\n".join(topics))
    elif args.command == "report":
        monitor.print_status_report()
    else:
        monitor.print_status_report()


if __name__ == "__main__":
    main()
