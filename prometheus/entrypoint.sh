#!/bin/sh
set -e

# Replace Supabase placeholders in prom.yml
if [ -n "$SUPABASE_PROJECT_REF" ] && [ -n "$SUPABASE_SERVICE_ROLE_KEY" ]; then
    echo "Replacing Supabase config placeholders..."
    sed -i "s/__SUPABASE_PROJECT_REF__/$SUPABASE_PROJECT_REF/g" /etc/prometheus/prom.yml
    sed -i "s/__SUPABASE_SERVICE_ROLE_KEY__/$SUPABASE_SERVICE_ROLE_KEY/g" /etc/prometheus/prom.yml
else
    echo "Warning: SUPABASE_PROJECT_REF or SUPABASE_SERVICE_ROLE_KEY not set. Prometheus metrics for Supabase might fail."
fi

# Replace ClickHouse Cloud placeholders in prom.yml
if [ -n "$CLICKHOUSE_CLOUD_KEY_ID" ] && [ -n "$CLICKHOUSE_CLOUD_KEY_SECRET" ]; then
    echo "Replacing ClickHouse Cloud config placeholders..."
    sed -i "s/__CLICKHOUSE_CLOUD_KEY_ID__/$CLICKHOUSE_CLOUD_KEY_ID/g" /etc/prometheus/prom.yml
    sed -i "s/__CLICKHOUSE_CLOUD_KEY_SECRET__/$CLICKHOUSE_CLOUD_KEY_SECRET/g" /etc/prometheus/prom.yml
else
    echo "Warning: CLICKHOUSE_CLOUD_KEY_ID or CLICKHOUSE_CLOUD_KEY_SECRET not set. ClickHouse Cloud metrics will fail."
fi

# Run the CMD passed to the docker container (which is prometheus)
exec /bin/prometheus "$@"
