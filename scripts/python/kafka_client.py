#!/usr/bin/env python3

"""
Kafka Client Library for AWS EKS-Strimzi
Example producer and consumer implementations
"""

import argparse
import json
import logging
from typing import Optional

from kafka import KafkaProducer, KafkaConsumer
from kafka.errors import KafkaError


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class KafkaClient:
    """Kafka client wrapper"""
    
    def __init__(self, bootstrap_servers: str, security_protocol: str = "PLAINTEXT"):
        self.bootstrap_servers = bootstrap_servers
        self.security_protocol = security_protocol
    
    def create_producer(self) -> KafkaProducer:
        """Create Kafka producer"""
        return KafkaProducer(
            bootstrap_servers=self.bootstrap_servers,
            security_protocol=self.security_protocol,
            value_serializer=lambda v: json.dumps(v).encode("utf-8"),
            acks="all"
        )
    
    def create_consumer(self, group_id: str, topic: str, auto_offset_reset: str = "earliest") -> KafkaConsumer:
        """Create Kafka consumer"""
        return KafkaConsumer(
            topic,
            bootstrap_servers=self.bootstrap_servers,
            security_protocol=self.security_protocol,
            group_id=group_id,
            auto_offset_reset=auto_offset_reset,
            value_deserializer=lambda m: json.loads(m.decode("utf-8"))
        )
    
    def send_message(self, topic: str, value: dict, key: Optional[str] = None):
        """Send message to topic"""
        producer = self.create_producer()
        
        try:
            future = producer.send(topic, value=value, key=key.encode() if key else None)
            record_metadata = future.get(timeout=10)
            logger.info(f"Message sent to {record_metadata.topic}:{record_metadata.partition}@{record_metadata.offset}")
        except KafkaError as e:
            logger.error(f"Failed to send message: {e}")
        finally:
            producer.close()
    
    def consume_messages(self, topic: str, group_id: str, count: int = 10):
        """Consume messages from topic"""
        consumer = self.create_consumer(group_id, topic)
        
        messages = []
        for i, message in enumerate(consumer):
            messages.append({
                "partition": message.partition,
                "offset": message.offset,
                "key": message.key.decode() if message.key else None,
                "value": message.value,
                "timestamp": message.timestamp
            })
            
            if i >= count - 1:
                break
        
        consumer.close()
        return messages


def main():
    parser = argparse.ArgumentParser(description="Kafka Client for EKS-Strimzi")
    parser.add_argument("--bootstrap-servers", default="kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092",
                        help="Kafka bootstrap servers")
    parser.add_argument("--security-protocol", default="PLAINTEXT", help="Security protocol")
    
    subparsers = parser.add_subparsers(dest="command", help="Command to run")
    
    # Send command
    send_parser = subparsers.add_parser("send", help="Send message")
    send_parser.add_argument("--topic", required=True, help="Topic name")
    send_parser.add_argument("--message", required=True, help="Message (JSON)")
    send_parser.add_argument("--key", help="Message key")
    
    # Consume command
    consume_parser = subparsers.add_parser("consume", help="Consume messages")
    consume_parser.add_argument("--topic", required=True, help="Topic name")
    consume_parser.add_argument("--group", required=True, help="Consumer group")
    consume_parser.add_argument("--count", type=int, default=10, help="Number of messages to consume")
    
    args = parser.parse_args()
    
    client = KafkaClient(args.bootstrap_servers, args.security_protocol)
    
    if args.command == "send":
        try:
            message = json.loads(args.message)
            client.send_message(args.topic, message, args.key)
        except json.JSONDecodeError:
            logger.error("Invalid JSON message")
    elif args.command == "consume":
        messages = client.consume_messages(args.topic, args.group, args.count)
        for msg in messages:
            print(json.dumps(msg, indent=2))
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
