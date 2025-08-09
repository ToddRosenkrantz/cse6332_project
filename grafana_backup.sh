#!/bin/bash
# Backup Grafana database to grafana.db in current directory
docker compose stop grafana
docker compose cp grafana:/var/lib/grafana/grafana.db ./grafana.db
docker compose start grafana
echo "✅ Grafana dashboard database backed up to grafana.db"
