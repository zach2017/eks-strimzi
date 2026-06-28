#!/usr/bin/env python3
"""
Python Kafka Monitor Application
Monitors Kafka cluster metrics and health
"""

import asyncio
import json
import logging
import os
from datetime import datetime
from typing import Dict, List, Any

from kafka import KafkaConsumer, KafkaProducer
from kafka.admin import KafkaAdminClient, ConfigResource, ConfigResourceType
from kafka.errors import KafkaError

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class KafkaMonitor:
    """Monitor Kafka cluster"""
    
    def __init__(self, bootstrap_servers: str = None):
        self.bootstrap_servers = bootstrap_servers or os.getenv(
            "KAFKA_BOOTSTRAP_SERVERS",
            "kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"
        )
        self.admin_client = KafkaAdminClient(bootstrap_servers=self.bootstrap_servers)
    
    def get_cluster_metadata(self) -> Dict[str, Any]:
        """Get cluster metadata"""
        try:
            metadata = self.admin_client.list_topics()
            brokers = self.admin_client.describe_cluster()
            
            return {
                "brokers": len(brokers.get("brokers", [])),
                "controller_id": brokers.get("controller"),
                "topics": len(metadata),
                "cluster_id": brokers.get("cluster_id"),
                "timestamp": datetime.now().isoformat()
            }
        except Exception as e:
            logger.error(f"Error getting cluster metadata: {e}")
            return {}
    
    def get_topics(self) -> List[str]:
        """Get list of topics"""
        try:
            topics = self.admin_client.list_topics()
            return list(topics.keys())
        except Exception as e:
            logger.error(f"Error getting topics: {e}")
            return []
    
    def get_topic_partitions(self, topic: str) -> Dict[str, Any]:
        """Get topic partition info"""
        try:
            partitions = self.admin_client.describe_topics(topics=[topic])
            if topic in partitions:
                return partitions[topic]
            return {}
        except Exception as e:
            logger.error(f"Error getting topic partitions: {e}")
            return {}
    
    def get_consumer_groups(self) -> List[str]:
        """Get list of consumer groups"""
        try:
            groups = self.admin_client.list_consumer_groups()
            return [g[0] for g in groups]
        except Exception as e:
            logger.error(f"Error getting consumer groups: {e}")
            return []
    
    def send_health_check_message(self, topic: str = "healthcheck") -> bool:
        """Send health check message"""
        try:
            producer = KafkaProducer(bootstrap_servers=self.bootstrap_servers)
            
            message = {
                "timestamp": datetime.now().isoformat(),
                "status": "healthy",
                "check_type": "kafka_monitor"
            }
            
            future = producer.send(topic, json.dumps(message).encode())
            record_metadata = future.get(timeout=5)
            
            logger.info(f"Health check message sent to {record_metadata.topic}:{record_metadata.partition}@{record_metadata.offset}")
            producer.close()
            return True
        except Exception as e:
            logger.error(f"Error sending health check message: {e}")
            return False
    
    def get_monitoring_stats(self) -> Dict[str, Any]:
        """Get monitoring statistics"""
        stats = {
            "timestamp": datetime.now().isoformat(),
            "cluster": self.get_cluster_metadata(),
            "topics": self.get_topics(),
            "consumer_groups": self.get_consumer_groups(),
            "health_check": self.send_health_check_message()
        }
        return stats
    
    def close(self):
        """Close admin client"""
        try:
            self.admin_client.close()
        except Exception as e:
            logger.error(f"Error closing admin client: {e}")


async def monitor_loop(monitor: KafkaMonitor, interval: int = 30):
    """Monitoring loop"""
    while True:
        try:
            stats = monitor.get_monitoring_stats()
            logger.info(f"Monitoring stats: {json.dumps(stats, indent=2)}")
            await asyncio.sleep(interval)
        except Exception as e:
            logger.error(f"Error in monitoring loop: {e}")
            await asyncio.sleep(interval)


if __name__ == "__main__":
    bootstrap_servers = os.getenv("KAFKA_BOOTSTRAP_SERVERS", 
                                  "kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092")
    monitor = KafkaMonitor(bootstrap_servers)
    
    try:
        asyncio.run(monitor_loop(monitor))
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        monitor.close()
