#!/bin/bash
# Restore Grafana database from grafana.db in current directory
if [ ! -f ./grafana.db ]; then
  echo "❌ grafana.db not found!"
  exit 1
fi
docker compose stop grafana
docker compose cp ./grafana.db grafana:/var/lib/grafana/grafana.db
docker compose start grafana
echo "✅ Grafana dashboard database restored and Grafana restarted"
