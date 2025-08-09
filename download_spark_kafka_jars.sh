#!/bin/bash
mkdir -p ./volumes/jars
mkdir -p ./volumes/jmx

download_if_missing() {
  local url=$1
  local dest_dir=$2
  local filename=$(basename "$url")
  local filepath="$dest_dir/$filename"

  if [ -f "$filepath" ]; then
    echo "✔️  $filename already exists, skipping."
  else
    echo "⬇️  Downloading $filename..."
    wget -q "$url" -P "$dest_dir" && echo "✅ $filename downloaded."
  fi
}

download_if_missing https://repo1.maven.org/maven2/org/apache/spark/spark-sql-kafka-0-10_2.12/3.5.0/spark-sql-kafka-0-10_2.12-3.5.0.jar ./volumes/jars
download_if_missing https://repo1.maven.org/maven2/org/apache/kafka/kafka-clients/3.5.0/kafka-clients-3.5.0.jar ./volumes/jars
download_if_missing https://repo1.maven.org/maven2/org/apache/spark/spark-token-provider-kafka-0-10_2.12/3.5.0/spark-token-provider-kafka-0-10_2.12-3.5.0.jar ./volumes/jars
download_if_missing https://repo1.maven.org/maven2/org/apache/commons/commons-pool2/2.11.1/commons-pool2-2.11.1.jar ./volumes/jars
download_if_missing https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.6/hadoop-aws-3.3.6.jar ./volumes/jars
download_if_missing https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar ./volumes/jars
download_if_missing https://repo1.maven.org/maven2/io/prometheus/simpleclient_dropwizard/0.16.0/simpleclient_dropwizard-0.16.0.jar ./volumes/jars
download_if_missing https://repo1.maven.org/maven2/org/apache/spark/spark-metrics_2.12/3.5.0/spark-metrics_2.12-3.5.0.jar ./volumes/jars

download_if_missing https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/1.0.1/jmx_prometheus_javaagent-1.0.1.jar ./volumes/jmx
