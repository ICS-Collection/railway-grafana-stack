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

# Run the CMD passed to the docker container (which is prometheus)
exec /bin/prometheus "$@"
