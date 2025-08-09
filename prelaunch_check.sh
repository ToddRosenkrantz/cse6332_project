#!/usr/bin/env bash

set -e

echo "🔐 Resetting ownership of all files and directories under $(pwd) to $USER"
sudo chown -R "$USER":"$USER" .

REQUIRED_DIRS=(
  "./volumes/kafka"
  "./volumes/zookeeper"
  "./volumes/minio"
  "./volumes/prometheus"
  "./volumes/grafana"
  "./volumes/spark-metrics"
  "./volumes/jars"
  "./jobs"
  "./volumes/jmx"
)

echo "🔍 Validating required volume directories..."
for dir in "${REQUIRED_DIRS[@]}"; do
  if [ ! -d "$dir" ]; then
    echo "❌ Directory missing: $dir"
    echo "   ➤ Creating..."
    mkdir -p "$dir"
  fi
done

echo "✅ All required directories exist."

echo "🔐 Setting correct ownerships and permissions..."
for dir in "${REQUIRED_DIRS[@]}"; do
  case "$dir" in
    *prometheus*)
      echo "🔧 Prometheus (UID 65534): $dir"
      sudo chown -R 65534:65534 "$dir"
      sudo chmod -R 755 "$dir"
      ;;
    *grafana*)
      echo "🔧 Grafana (UID 472): $dir"
      sudo chown -R 472:472 "$dir"
      sudo chmod -R 755 "$dir"
      ;;
    *kafka*|*zookeeper*|*jmx*)
      echo "🔧 Kafka/Zookeeper (UID 1001): $dir"
      sudo chown -R 1001:1001 "$dir"
      sudo chmod -R 744 "$dir"
      ;;
    *minio*)
      echo "🔧 MinIO (UID 1001): $dir"
      sudo chown -R 1001:1001 "$dir"
      sudo chmod -R 775 "$dir"
      ;;
    *jobs*)
      echo "🔧 Making jobs directory world-writable for dev: $dir"
      sudo chmod -R 777 "$dir"
      ;;
    *)
      echo "🔧 Default (Spark etc., UID 1001): $dir"
      sudo chown -R 1001:1001 "$dir"
      sudo chmod -R 700 "$dir"
      ;;
  esac
done

sudo chown 472:472 grafana.db

echo "✅ Permissions set."

echo "🚫 Checking for named Docker volumes that could override bind mounts..."
docker volume ls -q | grep -E '(_)?kafka|zookeeper|minio|prometheus|grafana' && {
  echo "⚠️  Potential named volumes exist. You can remove them with:"
  echo "    docker volume ls -q | grep project_root | xargs -r docker volume rm"
} || {
  echo "✅ No conflicting named volumes found."
}

echo "🔁 Validating docker-compose.yml syntax..."
docker-compose config >/dev/null && echo "✅ docker-compose.yml is valid." || {
  echo "❌ docker-compose.yml has errors!"
  exit 1
}

echo "✅ Prelaunch checks passed. You’re ready to run: DISABLE_JMX=true docker-compose up -d"
echo " once the containers are up, you need to ./create_kafka_topics.sh"
echo " then you need to run ./create_minio_bucket.sh"
echo " then you need to stop the containers and start them without the DISABLE_JMX=true with"
echo " docker-compose down && docker-compose up -d"
