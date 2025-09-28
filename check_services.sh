#!/bin/bash

# Function to check HTTP endpoint
check_http() {
  local name=$1
  local url=$2
  if curl --silent --show-error --fail "$url" > /dev/null; then
    echo "[OK] $name is reachable at $url"
  else
    echo "[FAIL] $name is not reachable at $url"
  fi
}

# Function to check TCP port
check_port() {
  local name=$1
  local host=$2
  local port=$3
  if nc -z -w 3 "$host" "$port"; then
    echo "[OK] $name port $port is open on $host"
  else
    echo "[FAIL] $name port $port is not open on $host"
  fi
}

# Zookeeper check
echo "Checking Zookeeper..."
check_port "Zookeeper" "localhost" 2181
check_zookeeper_ruok() {
  local host=$1
  local port=$2
  if echo ruok | nc "$host" "$port" | grep -q imok; then
    echo "[OK] Zookeeper responded to ruok"
  else
    echo "[FAIL] Zookeeper did not respond to ruok"
  fi
}

check_zookeeper_ruok "localhost" 2181
check_http "Zookeeper JMX Exporter" "http://localhost:7072/metrics"

# Kafka check
echo "Checking Kafka..."
check_port "Kafka" "localhost" 9092
check_http "Kafka JMX Exporter" "http://localhost:7071/metrics"

# Kafka Exporter
echo "Checking Kafka Exporter..."
check_http "Kafka Exporter" "http://localhost:9308/metrics"

# Zookeeper Exporter
echo "Checking Zookeeper Exporter..."
check_http "Zookeeper Exporter" "http://localhost:9141/metrics"

# Grafana
echo "Checking Grafana..."
check_http "Grafana" "http://localhost:3000/api/health"

# MinIO
echo "Checking MinIO..."
check_http "MinIO Console" "http://localhost:9001"
check_http "MinIO Health" "http://localhost:9000/minio/health/live"

# Prometheus
echo "Checking Prometheus..."
check_http "Prometheus" "http://localhost:9090/-/healthy"

# Spark Master
echo "Checking Spark Master..."
check_port "Spark Master RPC" "localhost" 7077
check_http "Spark Master UI" "http://localhost:8080"

# Spark Worker
echo "Checking Spark Worker UI..."
check_http "Spark Worker UI" "http://localhost:8081"

# Spark Consumers
echo "Checking Spark Consumer JSON UI..."
check_http "Spark Consumer JSON UI" "http://localhost:4041"

echo "Checking Spark Consumer Parquet UI..."
check_http "Spark Consumer Parquet UI" "http://localhost:4042"

# cAdvisor
echo "Checking cAdvisor..."
check_http "cAdvisor" "http://localhost:8088"

echo "All checks completed."
