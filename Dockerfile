ARG GRAFANA_VERSION=13.0.2
ARG LOKI_VERSION=3.7.9
ARG PROMETHEUS_VERSION=v3.15.0

FROM grafana/loki:${LOKI_VERSION} AS loki
FROM prom/prometheus:${PROMETHEUS_VERSION} AS prometheus
FROM grafana/grafana-oss:${GRAFANA_VERSION}

USER root

RUN apk add --no-cache bash sqlite curl tar gzip ca-certificates

# Copy Loki and Prometheus binaries
COPY --from=loki /usr/bin/loki /usr/local/bin/loki
COPY --from=prometheus /bin/prometheus /usr/local/bin/prometheus

# Copy Grafana provisioning and dashboards
COPY grafana/datasources /etc/grafana/provisioning/datasources
COPY grafana/provisioning/dashboards /etc/grafana/provisioning/dashboards
COPY grafana/dashboards /etc/grafana/dashboards

# Copy Loki and Prometheus configs
COPY loki/loki.yml /etc/loki/loki-config.yaml
COPY prometheus/prom.yml /etc/prometheus/prom.yml.template

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3000 3100

ENTRYPOINT ["/entrypoint.sh"]
