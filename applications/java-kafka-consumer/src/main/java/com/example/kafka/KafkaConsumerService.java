package com.example.kafka;

import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

/**
 * Kafka consumer service
 */
@Slf4j
@Service
public class KafkaConsumerService {

    @KafkaListener(topics = "example-topic", groupId = "java-consumer-group")
    public void consume(String message) {
        log.info("Received message: {}", message);
        // Process message
        processMessage(message);
    }

    private void processMessage(String message) {
        try {
            log.info("Processing message: {}", message);
            // Add business logic here
        } catch (Exception e) {
            log.error("Error processing message", e);
        }
    }
}
