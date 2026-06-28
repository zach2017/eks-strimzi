@echo off
REM ============================================================================
REM Kubernetes Management Script (Windows)
REM ============================================================================

setlocal enabledelayedexpansion

if "!%1!"=="" (
    echo Usage: %0 [COMMAND] [OPTIONS]
    echo.
    echo Commands:
    echo   pods [NAMESPACE]              Check pod status
    echo   topics [NAMESPACE]            List topics
    echo   topic-create NAME [PART] [REP] Create topic
    echo   topic-delete NAME [NAMESPACE] Delete topic
    echo   status [NAMESPACE]            Show cluster status
    echo.
    exit /b 0
)

set NAMESPACE=%2
if "!NAMESPACE!"=="" set NAMESPACE=kafka

set COMMAND=%1

if "!COMMAND!"=="pods" (
    echo [INFO] Checking pod status in namespace !NAMESPACE!...
    call kubectl get pods -n !NAMESPACE! -o wide
) else if "!COMMAND!"=="topics" (
    echo [INFO] Kafka topics:
    call kubectl get kafkatopics -n !NAMESPACE!
) else if "!COMMAND!"=="topic-create" (
    set TOPIC_NAME=%2
    set PARTITIONS=%3
    set REPLICAS=%4
    if "!TOPIC_NAME!"=="" (
        echo [ERROR] Topic name required
        exit /b 1
    )
    if "!PARTITIONS!"=="" set PARTITIONS=3
    if "!REPLICAS!"=="" set REPLICAS=3
    echo [INFO] Creating topic: !TOPIC_NAME! ^(partitions: !PARTITIONS!, replicas: !REPLICAS!^)...
    (
        echo apiVersion: kafka.strimzi.io/v1beta2
        echo kind: KafkaTopic
        echo metadata:
        echo   name: !TOPIC_NAME!
        echo   namespace: !NAMESPACE!
        echo   labels:
        echo     strimzi.io/cluster: kafka-cluster
        echo spec:
        echo   partitions: !PARTITIONS!
        echo   replicationFactor: !REPLICAS!
    ) | kubectl apply -f -
) else if "!COMMAND!"=="status" (
    echo [INFO] Cluster status:
    echo.
    echo === Kafka Cluster ===
    call kubectl get kafka -n !NAMESPACE!
    echo.
    echo === Pods ===
    call kubectl get pods -n !NAMESPACE! -l strimzi.io/cluster=kafka-cluster
) else (
    echo [ERROR] Unknown command: !COMMAND!
    exit /b 1
)

endlocal
