# scripts/monitoring/setup.sh
#!/bin/bash

setup_monitoring() {
    log_message "INFO" "Setting up monitoring system..."

    # Install required packages
    apt-get install -y \
        prometheus \
        prometheus-node-exporter \
        grafana \
        nginx-prometheus-exporter

    # Setup components
    setup_prometheus
    setup_node_exporter
    setup_nginx_exporter
    setup_grafana
}

setup_prometheus() {
    local config_file="/etc/prometheus/prometheus.yml"
    
    cat > "$config_file" <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - localhost:9093

rule_files:
  - "/etc/prometheus/rules/*.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'nginx'
    static_configs:
      - targets: ['localhost:9113']

  - job_name: 'mysql'
    static_configs:
      - targets: ['localhost:9104']

  - job_name: 'php-fpm'
    static_configs:
      - targets: ['localhost:9253']
EOF

    # Setup alert rules
    mkdir -p /etc/prometheus/rules
    setup_prometheus_rules

    # Start service
    systemctl enable prometheus
    systemctl restart prometheus
}

setup_prometheus_rules() {
    cat > "/etc/prometheus/rules/alerts.yml" <<EOF
groups:
- name: basic_alerts
  rules:
  - alert: HighCPUUsage
    expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: High CPU usage detected
      description: CPU usage is above 80% for 5 minutes

  - alert: HighMemoryUsage
    expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: High memory usage detected
      description: Memory usage is above 80% for 5 minutes

  - alert: HighDiskUsage
    expr: 100 - ((node_filesystem_avail_bytes * 100) / node_filesystem_size_bytes) > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: High disk usage detected
      description: Disk usage is above 80%

  - alert: ServiceDown
    expr: up == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: Service is down
      description: "{{ $labels.job }} service is down"
EOF
}

setup_node_exporter() {
    # Create systemd service
    cat > "/etc/systemd/system/node_exporter.service" <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=prometheus
ExecStart=/usr/bin/node_exporter \
    --collector.filesystem.ignored-mount-points="^/(sys|proc|dev)($|/)" \
    --collector.systemd \
    --collector.processes

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable node_exporter
    systemctl restart node_exporter
}

setup_nginx_exporter() {
    # Create systemd service
    cat > "/etc/systemd/system/nginx-prometheus-exporter.service" <<EOF
[Unit]
Description=NGINX Prometheus Exporter
After=network.target

[Service]
ExecStart=/usr/bin/nginx-prometheus-exporter \
    -nginx.scrape-uri=http://localhost/nginx_status

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable nginx-prometheus-exporter
    systemctl restart nginx-prometheus-exporter
}

setup_grafana() {
    # Update Grafana configuration
    cat > "/etc/grafana/grafana.ini" <<EOF
[server]
protocol = http
http_addr = localhost
http_port = 3000

[security]
admin_user = admin
admin_password = ${GRAFANA_ADMIN_PASSWORD:-admin}

[auth.anonymous]
enabled = false

[smtp]
enabled = ${ENABLE_EMAIL_NOTIFICATIONS:-false}
host = ${SMTP_HOST:-localhost}:${SMTP_PORT:-25}
user = ${SMTP_USER}
password = ${SMTP_PASSWORD}
from_address = ${NOTIFICATION_EMAIL}
from_name = Grafana
EOF

    # Setup dashboards
    mkdir -p /etc/grafana/provisioning/dashboards
    mkdir -p /etc/grafana/provisioning/datasources
    
    # Add Prometheus datasource
    cat > "/etc/grafana/provisioning/datasources/prometheus.yml" <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
EOF

    setup_grafana_dashboards

    systemctl enable grafana-server
    systemctl restart grafana-server
}