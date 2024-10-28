# scripts/monitoring/maintenance-monitor.sh
#!/bin/bash

# Maintenance monitoring script
MONITOR_CONFIG="/etc/multisite-server/monitoring.conf"
METRICS_DIR="/var/lib/multisite-server/metrics"
PROMETHEUS_DIR="/etc/prometheus/textfile_collector"

# Initialize monitoring
setup_maintenance_monitoring() {
    local domain=$1
    
    # Create monitoring directories
    mkdir -p "${METRICS_DIR}/${domain}"
    mkdir -p "$PROMETHEUS_DIR"
    
    # Setup monitoring configuration
    cat > "${MONITOR_CONFIG}.${domain}" <<EOF
# Maintenance monitoring configuration for ${domain}
monitor_interval=60
alert_threshold=1800  # Alert if maintenance exceeds expected duration by 30 minutes
metrics_retention=30  # Days to keep metrics
notification_email="${ADMIN_EMAIL}"
pushgateway_url="http://localhost:9091"
prometheus_enabled=true
grafana_enabled=true

# Slack webhook (optional)
#slack_webhook="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Teams webhook (optional)
#teams_webhook="https://outlook.office.com/webhook/YOUR/WEBHOOK/URL"

# Maintenance status check endpoints
endpoints=(
    "https://${domain}"
    "https://${domain}/api/health"
)
EOF

    # Create Prometheus metrics file
    cat > "${PROMETHEUS_DIR}/maintenance_${domain}.prom.tmp" <<EOF
# HELP maintenance_mode_active Whether maintenance mode is active (1 for active, 0 for inactive)
# TYPE maintenance_mode_active gauge
maintenance_mode_active{domain="${domain}"} 0

# HELP maintenance_duration_seconds Duration of current or last maintenance in seconds
# TYPE maintenance_duration_seconds gauge
maintenance_duration_seconds{domain="${domain}"} 0

# HELP maintenance_last_start_timestamp Unix timestamp of the last maintenance start
# TYPE maintenance_last_start_timestamp gauge
maintenance_last_start_timestamp{domain="${domain}"} 0

# HELP maintenance_completed_total Total number of completed maintenance operations
# TYPE maintenance_completed_total counter
maintenance_completed_total{domain="${domain}"} 0
EOF

    mv "${PROMETHEUS_DIR}/maintenance_${domain}.prom.tmp" "${PROMETHEUS_DIR}/maintenance_${domain}.prom"
}

# Update Prometheus metrics
update_prometheus_metrics() {
    local domain=$1
    local status=$2
    local start_time=$3
    local duration=$4
    
    cat > "${PROMETHEUS_DIR}/maintenance_${domain}.prom.tmp" <<EOF
# HELP maintenance_mode_active Whether maintenance mode is active (1 for active, 0 for inactive)
# TYPE maintenance_mode_active gauge
maintenance_mode_active{domain="${domain}"} ${status}

# HELP maintenance_duration_seconds Duration of current or last maintenance in seconds
# TYPE maintenance_duration_seconds gauge
maintenance_duration_seconds{domain="${domain}"} ${duration}

# HELP maintenance_last_start_timestamp Unix timestamp of the last maintenance start
# TYPE maintenance_last_start_timestamp gauge
maintenance_last_start_timestamp{domain="${domain}"} ${start_time}

# HELP maintenance_progress_percent Current maintenance progress percentage
# TYPE maintenance_progress_percent gauge
maintenance_progress_percent{domain="${domain}"} ${progress}
EOF

    mv "${PROMETHEUS_DIR}/maintenance_${domain}.prom.tmp" "${PROMETHEUS_DIR}/maintenance_${domain}.prom"
}

# Grafana dashboard configuration
setup_grafana_dashboard() {
    local domain=$1
    
    cat > "/etc/grafana/provisioning/dashboards/maintenance_${domain}.json" <<'EOF'
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "panels": [
    {
      "title": "Maintenance Status",
      "type": "stat",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "maintenance_mode_active{domain=\"$domain\"}",
          "instant": true
        }
      ],
      "fieldConfig": {
        "defaults": {
          "mappings": [
            {
              "from": "0",
              "text": "Inactive",
              "to": "0",
              "type": 1,
              "value": "0"
            },
            {
              "from": "1",
              "text": "Active",
              "to": "1",
              "type": 1,
              "value": "1"
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "orange",
                "value": 1
              }
            ]
          }
        }
      }
    },
    {
      "title": "Maintenance Progress",
      "type": "gauge",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "maintenance_progress_percent{domain=\"$domain\"}",
          "instant": true
        }
      ],
      "fieldConfig": {
        "defaults": {
          "max": 100,
          "min": 0,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "red",
                "value": null
              },
              {
                "color": "orange",
                "value": 33
              },
              {
                "color": "yellow",
                "value": 66
              },
              {
                "color": "green",
                "value": 90
              }
            ]
          },
          "unit": "percent"
        }
      }
    },
    {
      "title": "Maintenance Duration",
      "type": "timeseries",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "maintenance_duration_seconds{domain=\"$domain\"}",
          "legendFormat": "Duration"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "s"
        }
      }
    }
  ],
  "templating": {
    "list": [
      {
        "current": {
          "value": "${domain}"
        },
        "name": "domain",
        "type": "constant"
      }
    ]
  }
}
EOF
}

# Create alert rules
setup_alerting_rules() {
    local domain=$1
    
    cat > "/etc/prometheus/rules/maintenance_${domain}.yml" <<EOF
groups:
- name: maintenance_alerts
  rules:
  - alert: MaintenanceExceededDuration
    expr: maintenance_mode_active{domain="${domain}"} == 1 and maintenance_duration_seconds > scalar(maintenance_duration_seconds{domain="${domain}"} offset 5m) + 1800
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Maintenance exceeded expected duration"
      description: "Maintenance for ${domain} has exceeded the expected duration by 30 minutes"

  - alert: MaintenanceStuck
    expr: maintenance_progress_percent{domain="${domain}"} > 0 and maintenance_progress_percent{domain="${domain}"} < scalar(maintenance_progress_percent{domain="${domain}"} offset 15m)
    for: 15m
    labels:
      severity: critical
    annotations:
      summary: "Maintenance progress stuck"
      description: "Maintenance progress for ${domain} has not increased in 15 minutes"
EOF
}

# Monitoring functions for maintenance script
monitor_maintenance_start() {
    local domain=$1
    local duration=$2
    local message=$3
    
    # Record start time
    echo "$(date +%s)" > "${METRICS_DIR}/${domain}/start_time"
    
    # Update Prometheus metrics
    update_prometheus_metrics "$domain" 1 "$(date +%s)" "$duration" 0
    
    # Send notification
    notify_maintenance_status "$domain" "start" "$message" "$duration"
}

monitor_maintenance_progress() {
    local domain=$1
    local progress=$2
    
    # Update Prometheus metrics
    local start_time=$(cat "${METRICS_DIR}/${domain}/start_time")
    local current_time=$(date +%s)
    local duration=$((current_time - start_time))
    
    update_prometheus_metrics "$domain" 1 "$start_time" "$duration" "$progress"
}

monitor_maintenance_complete() {
    local domain=$1
    
    # Update Prometheus metrics
    update_prometheus_metrics "$domain" 0 0 0 100
    
    # Send notification
    notify_maintenance_status "$domain" "complete" "Maintenance completed successfully"
}

notify_maintenance_status() {
    local domain=$1
    local status=$2
    local message=$3
    local duration=$4
    
    # Load configuration
    source "${MONITOR_CONFIG}.${domain}"
    
    # Email notification
    if [[ -n "$notification_email" ]]; then
        send_email_notification "$domain" "$status" "$message" "$duration"
    fi
    
    # Slack notification
    if [[ -n "${slack_webhook:-}" ]]; then
        send_slack_notification "$domain" "$status" "$message" "$duration"
    fi
    
    # Teams notification
    if [[ -n "${teams_webhook:-}" ]]; then
        send_teams_notification "$domain" "$status" "$message" "$duration"
    fi
}

# Update maintenance script to use monitoring
maintenance_wrapper() {
    local domain=$1
    local action=$2
    local duration=$3
    local message=$4
    
    case "$action" in
        start)
            monitor_maintenance_start "$domain" "$duration" "$message"
            ;;
        progress)
            monitor_maintenance_progress "$domain" "$3"
            ;;
        complete)
            monitor_maintenance_complete "$domain"
            ;;
    esac
}