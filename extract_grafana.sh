# stop grafana so it doesn't write while we copy files out
mkdir -p grafana_export/provisioning
mkdir -p grafana_export/plugins
docker stop grafana
# grafana.db (core dashboards and data sources)
docker cp grafana:/var/lib/grafana/grafana.db ./grafana_export/grafana.db

# Provisioned dashboards (if used)
docker cp grafana:/etc/grafana/provisioning/dashboards ./grafana_export/provisioning/dashboards

# Provisioned data sources (if used)
docker cp grafana:/etc/grafana/provisioning/datasources ./grafana_export/provisioning/datasources

# Plugins (if custom plugins are installed)
docker cp grafana:/var/lib/grafana/plugins ./grafana_export/plugins
