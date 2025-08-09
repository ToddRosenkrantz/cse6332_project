#!/bin/bash

echo "=== Step 1: Checking Kafka Topics ==="
docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --list

echo -e "\n=== Step 2A: Describing topic 'topic-json' ==="
docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic topic-json

echo -e "\n=== Step 2B: Describing topic 'topic-parq' ==="
docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic topic-parq


echo -e "\n=== Step 3A: Kafka Partitions & Offsets ==="
docker exec kafka kafka-run-class.sh kafka.tools.GetOffsetShell --broker-list localhost:9092 --topic topic-json --time -1

echo -e "\n=== Step 3b: Kafka Partitions & Offsets ==="
docker exec kafka kafka-run-class.sh kafka.tools.GetOffsetShell --broker-list localhost:9092 --topic topic-parq --time -1

echo -e "\n=== Step 4A: Spark Consumer Logs JSON ==="
docker logs --tail 3 spark-consumer-json

echo -e "\n=== Step 4B: Spark Consumer Logs Parquet ==="
docker logs --tail 3 spark-consumer-parquet

echo -e "\n=== Step 5A: Recent Spark Checkpoint Files (json) ==="
docker exec spark-consumer-json sh -c '
  ls -lt /tmp/json-checkpoint/offsets 2>/dev/null | head -n 3
' || echo "❌ JSON checkpoint directory not found"

echo -e "\n=== Step 5B: Recent Spark Checkpoint Files (parquet) ==="
docker exec spark-consumer-parquet sh -c '
  ls -lt /tmp/parquet-checkpoint/offsets 2>/dev/null | head -n 3
' || echo "❌ Parquet checkpoint directory not found"

echo -e "\n=== Step 6A: MinIO Output Files (json - 2 most recent) ==="
MINIO_USER=$(docker exec minio printenv MINIO_ROOT_USER)
MINIO_PASS=$(docker exec minio printenv MINIO_ROOT_PASSWORD)

if ! docker exec minio mc alias list | grep -q 'local'; then
  docker exec minio sh -c '
    mc alias set local http://localhost:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
  ' >/dev/null 2>&1
fi

docker exec minio sh -c '
  mc ls --recursive data/spark-output/json 2>/dev/null | sort -k1,2r | head -n 2
' || echo "❌ No JSON output found in MinIO"

echo -e "\n=== Step 6B: MinIO Output Files (parquet - 2 most recent) ==="
docker exec minio sh -c '
  mc ls --recursive data/spark-output/parquet 2>/dev/null | sort -k1,2r | head -n 2
' || echo "❌ No Parquet output found in MinIO"

echo -e "\n=== Step 7: Pipeline Check Complete ==="
