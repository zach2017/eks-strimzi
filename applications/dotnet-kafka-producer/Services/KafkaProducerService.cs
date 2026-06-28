using Confluent.Kafka;
using Microsoft.Extensions.Logging;
using System;
using System.Text.Json;
using System.Threading.Tasks;

namespace KafkaProducer.Services
{
    /// <summary>
    /// Kafka producer service
    /// </summary>
    public class KafkaProducerService
    {
        private readonly ILogger<KafkaProducerService> _logger;
        private readonly IProducer<string, string> _producer;

        public KafkaProducerService(ILogger<KafkaProducerService> logger)
        {
            _logger = logger;
            
            var config = new ProducerConfig
            {
                BootstrapServers = Environment.GetEnvironmentVariable("KAFKA_BOOTSTRAP_SERVERS") 
                    ?? "kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092",
                Acks = Acks.All,
                Retries = 3,
                CompressionType = CompressionType.Snappy
            };

            _producer = new ProducerBuilder<string, string>(config)
                .SetErrorHandler((_, e) => _logger.LogError($"Kafka error: {e.Reason}"))
                .Build();
        }

        /// <summary>
        /// Send message to Kafka topic
        /// </summary>
        public async Task SendMessageAsync(string topic, string key, object value)
        {
            try
            {
                var jsonValue = JsonSerializer.Serialize(value);
                
                var result = await _producer.ProduceAsync(topic, new Message<string, string>
                {
                    Key = key,
                    Value = jsonValue
                });

                _logger.LogInformation($"Message produced to {result.Topic}:{result.Partition}@{result.Offset}");
            }
            catch (ProduceException<string, string> e)
            {
                _logger.LogError($"Failed to produce message: {e.Error.Reason}");
                throw;
            }
        }

        /// <summary>
        /// Flush pending messages
        /// </summary>
        public void Flush(TimeSpan timeout)
        {
            _producer.Flush(timeout);
        }

        public void Dispose()
        {
            _producer?.Dispose();
        }
    }
}
