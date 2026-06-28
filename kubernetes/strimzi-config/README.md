# Strimzi Configuration Examples

## Kafka Cluster Configuration

For production deployments, configure Kafka brokers with optimized settings:

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: kafka-cluster
  namespace: kafka
spec:
  kafka:
    version: 3.7.0
    replicas: 3
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
        authentication:
          type: scram-sha-512
    config:
      auto.create.topics.enable: "false"
      default.replication.factor: 3
      min.insync.replicas: 2
      log.retention.hours: 168
      compression.type: snappy
  zookeeper:
    replicas: 3
  entityOperator:
    topicOperator: {}
    userOperator: {}
```

## Topic Configuration

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: my-topic
  namespace: kafka
  labels:
    strimzi.io/cluster: kafka-cluster
spec:
  partitions: 3
  replicationFactor: 3
  config:
    retention.ms: 604800000  # 7 days
    cleanup.policy: delete
    compression.type: snappy
```

## User Configuration

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: app-user
  namespace: kafka
  labels:
    strimzi.io/cluster: kafka-cluster
spec:
  authentication:
    type: scram-sha-512
  authorization:
    type: simple
    acls:
      - resource:
          type: topic
          name: "my-*"
        operations:
          - Read
          - Write
      - resource:
          type: group
          name: "app-*"
        operations:
          - Read
```
