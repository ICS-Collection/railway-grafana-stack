#!/bin/bash
set -e

# Ensure persistent subdirectories exist on the Fly volume (/data)
mkdir -p /data/grafana /data/grafana/plugins /data/grafana/logs \
         /data/loki /data/loki/tsdb-index /data/loki/tsdb-cache /data/loki/compactor /data/loki/chunks /data/loki/rules \
         /data/prometheus

# Rescue any chunks/indexes written to ephemeral rootfs if present
if [ -d /usr/share/grafana/fake ]; then
    cp -a /usr/share/grafana/fake /data/loki/chunks/ && rm -rf /usr/share/grafana/fake
fi
if [ -d /usr/share/grafana/index ]; then
    cp -a /usr/share/grafana/index /data/loki/chunks/ && rm -rf /usr/share/grafana/index
fi

# Maintain exact path compatibility with Railway volume paths
rm -rf /loki /prometheus /var/lib/grafana
ln -sfn /data/loki /loki
ln -sfn /data/prometheus /prometheus
ln -sfn /data/grafana /var/lib/grafana

# Ensure provisioned Loki datasource uses server-side proxy over localhost
sed -i 's/access: direct/access: proxy/g' /etc/grafana/provisioning/datasources/datasources.yml || true

# Render Prometheus config from template with secrets
cp /etc/prometheus/prom.yml.template /etc/prometheus/prom.yml
if [ -n "$SUPABASE_PROJECT_REF" ] && [ -n "$SUPABASE_SERVICE_ROLE_KEY" ]; then
    echo "Replacing Supabase config placeholders..."
    sed -i "s|__SUPABASE_PROJECT_REF__|$SUPABASE_PROJECT_REF|g" /etc/prometheus/prom.yml
    sed -i "s|__SUPABASE_SERVICE_ROLE_KEY__|$SUPABASE_SERVICE_ROLE_KEY|g" /etc/prometheus/prom.yml
else
    echo "Warning: SUPABASE_PROJECT_REF or SUPABASE_SERVICE_ROLE_KEY not set."
fi

if [ -n "$CLICKHOUSE_CLOUD_KEY_ID" ] && [ -n "$CLICKHOUSE_CLOUD_KEY_SECRET" ]; then
    echo "Replacing ClickHouse Cloud config placeholders..."
    sed -i "s|__CLICKHOUSE_CLOUD_KEY_ID__|$CLICKHOUSE_CLOUD_KEY_ID|g" /etc/prometheus/prom.yml
    sed -i "s|__CLICKHOUSE_CLOUD_KEY_SECRET__|$CLICKHOUSE_CLOUD_KEY_SECRET|g" /etc/prometheus/prom.yml
else
    echo "Warning: CLICKHOUSE_CLOUD_KEY_ID or CLICKHOUSE_CLOUD_KEY_SECRET not set."
fi

# Ensure migrated Grafana SQLite DB points datasources to localhost proxy
if [ -f /data/grafana/grafana.db ]; then
    sqlite3 /data/grafana/grafana.db "UPDATE data_source SET url='http://127.0.0.1:3100', access='proxy' WHERE type='loki';" || true
    sqlite3 /data/grafana/grafana.db "UPDATE data_source SET url='http://127.0.0.1:9090', access='proxy' WHERE type='prometheus';" || true
fi

# Forward termination signals cleanly so Loki/Prometheus flush WAL/TSDB on shutdown
trap 'kill -TERM $(jobs -p) 2>/dev/null || true; wait' SIGTERM SIGINT

# 1. Start Loki (:3100) with working directory set to /data/loki/chunks
(cd /data/loki/chunks && GOMEMLIMIT=1000MiB GOGC=80 /usr/local/bin/loki \
    -config.file=/etc/loki/loki-config.yaml) &

# 2. Start Prometheus (127.0.0.1:9090 internal only)
GOMEMLIMIT=500MiB GOGC=80 /usr/local/bin/prometheus \
    --config.file=/etc/prometheus/prom.yml \
    --storage.tsdb.path=/data/prometheus \
    --storage.tsdb.retention.time=30d \
    --web.listen-address=127.0.0.1:9090 &

# 3. Start Grafana (:3000)
GOMEMLIMIT=300MiB \
GF_PATHS_DATA=/data/grafana \
GF_PATHS_LOGS=/data/grafana/logs \
GF_PATHS_PLUGINS=/data/grafana/plugins \
GF_PATHS_PROVISIONING=/etc/grafana/provisioning \
GF_SERVER_HTTP_ADDR=0.0.0.0 \
GF_SERVER_HTTP_PORT=3000 \
LOKI_INTERNAL_URL=http://127.0.0.1:3100 \
PROMETHEUS_INTERNAL_URL=http://127.0.0.1:9090 \
/run.sh &

# Wait for any process to exit (pause exit only if /tmp/migrating lockfile is active during volume import)
while true; do
    wait -n || true
    if [ -f /tmp/migrating ]; then
        sleep 2
        continue
    fi
    kill -TERM $(jobs -p) 2>/dev/null || true
    exit 1
done
