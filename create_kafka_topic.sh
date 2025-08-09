#!/bin/bash
# Create Kafka topic 'test-topic' if it doesn't already exist
# Assumes Kafka is running locally in Docker and exposes 9092

#docker exec -e KAFKA_OPTS='' kafka kafka-topics --create \
#       --topic test-topic --bootstrap-server localhost:9092 \
#       --partitions 1 --replication-factor 1
#docker exec -e KAFKA_OPTS='' kafka kafka-topics --create \
#       --topic topic-json --bootstrap-server localhost:9092 \
#       --partitions 1 --replication-factor 1
#docker exec -e KAFKA_OPTS='' kafka kafka-topics --create \
#        --topic topic-parq --bootstrap-server localhost:9092 \
#        --partitions 1 --replication-factor 1

docker exec -e KAFKA_OPTS='' kafka kafka-topics.sh --create \
       --topic test-topic --bootstrap-server localhost:9092 \
       --partitions 1 --replication-factor 1 || echo "Topic 'test-topic' already exists"
docker exec -e KAFKA_OPTS='' kafka kafka-topics.sh --create \
       --topic topic-json --bootstrap-server localhost:9092 \
       --partitions 1 --replication-factor 1 || echo "Topic 'topic-json' already exists"
docker exec -e KAFKA_OPTS='' kafka kafka-topics.sh --create \
        --topic topic-parq --bootstrap-server localhost:9092 \
        --partitions 1 --replication-factor 1 || echo "Topic 'topic-parq' already exists"